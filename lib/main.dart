// app.dart - Complete Multi-Tenant SaaS System
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mpcm/app.dart';
import 'package:mpcm/settings.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'analytics_screen.dart';
import 'firebase_options.dart';

class SuperAdminHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // System Overview
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                'Total Tenants',
                tenantProvider.tenants.length.toString(),
                Icons.business,
                Colors.blue,
              ),
              _StatCard(
                'Active Tenants',
                tenantProvider.tenants
                    .where((t) => t.isSubscriptionActive)
                    .length
                    .toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _StatCard(
                'Expired Tenants',
                tenantProvider.tenants
                    .where((t) => !t.isSubscriptionActive)
                    .length
                    .toString(),
                Icons.error,
                Colors.red,
              ),
            ],
          ),

          SizedBox(height: 20),

          // Quick Actions
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    childAspectRatio: 3,
                    children: [
                      _ActionCard(
                        'Create Tenant',
                        Icons.add_business,
                        Colors.blue,
                        () {
                          showDialog(
                            context: context,
                            builder: (context) => CreateTenantDialog(),
                          );
                        },
                      ),
                      _ActionCard(
                        'View All Tenants',
                        Icons.list_alt,
                        Colors.green,
                        () {
                          // Navigate to tenants management
                          final superAdminState = context
                              .findAncestorStateOfType<
                                _SuperAdminDashboardState
                              >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                                1; // Tenants tab index
                          });
                        },
                      ),
                      _ActionCard(
                        'System Analytics',
                        Icons.analytics,
                        Colors.orange,
                        () {
                          final superAdminState = context
                              .findAncestorStateOfType<
                                _SuperAdminDashboardState
                              >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                                2; // Analytics tab index
                          });
                        },
                      ),
                      _ActionCard(
                        'Support Tickets',
                        Icons.support,
                        Colors.purple,
                        () {
                          final superAdminState = context
                              .findAncestorStateOfType<
                                _SuperAdminDashboardState
                              >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                                3; // Support tab index
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Recent Tenants
          Expanded(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Tenants',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: () {
                            final superAdminState = context
                                .findAncestorStateOfType<
                                  _SuperAdminDashboardState
                                >();
                            superAdminState?.setState(() {
                              superAdminState._currentIndex =
                                  1; // Tenants tab index
                            });
                          },
                          child: Text('View All'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: tenantProvider.tenants.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No Tenants Yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            CreateTenantDialog(),
                                      );
                                    },
                                    icon: Icon(Icons.add_business),
                                    label: Text('Create First Tenant'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: tenantProvider.tenants.take(5).length,
                              itemBuilder: (context, index) {
                                final tenant = tenantProvider.tenants[index];
                                return ListTile(
                                  leading: Icon(
                                    Icons.business,
                                    color: tenant.isSubscriptionActive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: Text(tenant.businessName),
                                  subtitle: Text(
                                    '${tenant.subscriptionPlan} - ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry)}',
                                  ),
                                  trailing: tenant.isSubscriptionActive
                                      ? Chip(
                                          label: Text(
                                            'Active',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                        )
                                      : Chip(
                                          label: Text(
                                            'Expired',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                  onTap: () {
                                    // Show tenant details
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          TenantDetailsDialog(tenant: tenant),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Update the _ActionCard widget for better styling
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionCard(this.title, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Hive for offline storage
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    await Hive.openBox('app_cache');
    await Hive.openBox('offline_data');

    runApp(MultiTenantSaaSApp());
  } catch (e) {
    print('Firebase initialization error: $e');
    runApp(ErrorApp(error: e));
  }
}

class ErrorApp extends StatelessWidget {
  final dynamic error;

  const ErrorApp({Key? key, required this.error}) : super(key: key);

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
  static Future<void> createSuperAdminUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return await _handleFirebaseCall(() async {
      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Create super admin document
      await _firestore
          .collection('super_admins')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'role': 'super_admin',
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'permissions': {
              'manage_tenants': true,
              'manage_system': true,
              'view_analytics': true,
              'manage_tickets': true,
            },
          });

      return;
    });
  }

  static Future<bool> checkSuperAdminExists() async {
    try {
      final snapshot = await _firestore
          .collection('super_admins')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Enhanced error handling wrapper
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

  // Tenant management
  // Update the createTenant method in FirebaseService
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

      // Create admin user using the new method
      await createUserInTenant(
        tenantId: tenantId,
        email: adminEmail,
        password: adminPassword,
        role: 'clientAdmin', // Use string value instead of enum
        createdBy: 'system',
      );

      return;
    });
  }

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
  static Future<void> createTicket({
    required String tenantId,
    required String userId,
    required String subject,
    required String message,
    List<String>? attachments,
  }) async {
    return await _handleFirebaseCall(() async {
      await _firestore.collection('tickets').add({
        'tenantId': tenantId,
        'userId': userId,
        'subject': subject,
        'message': message,
        'attachments': attachments ?? [],
        'status': TicketStatus.open.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    });
  }

  static Future<void> updateTicket({
    required String ticketId,
    required String status,
    String? reply,
    String? assignedTo,
  }) async {
    return await _handleFirebaseCall(() async {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reply != null) {
        updateData['replies'] = FieldValue.arrayUnion([
          {
            'message': reply,
            'userId': FirebaseAuth.instance.currentUser!.uid,
            'timestamp': FieldValue.serverTimestamp(),
          },
        ]);
      }

      if (assignedTo != null) {
        updateData['assignedTo'] = assignedTo;
      }

      await _firestore.collection('tickets').doc(ticketId).update(updateData);
      return;
    });
  }

  // User management
  static Future<void> createUser({
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
  } // Analytics and reporting

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
        final data = doc.data() as Map<String, dynamic>;
        return sum + (data['totalAmount'] as double);
      });

      final totalSales = salesSnapshot.docs.length;
      final lowStockProducts = productsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
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
}

// =============================
// ENUMS AND MODELS
// =============================
enum UserRole { superAdmin, clientAdmin, cashier, salesInventoryManager }

enum TicketStatus { open, inProgress, closed }

class Tenant {
  final String id;
  final String businessName;
  final String subscriptionPlan;
  final DateTime subscriptionExpiry;
  final bool isActive;
  final Map<String, dynamic> branding;

  Tenant({
    required this.id,
    required this.businessName,
    required this.subscriptionPlan,
    required this.subscriptionExpiry,
    required this.isActive,
    required this.branding,
  });

  factory Tenant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tenant(
      id: doc.id,
      businessName: data['businessName'] ?? '',
      subscriptionPlan: data['subscriptionPlan'] ?? 'monthly',
      subscriptionExpiry: (data['subscriptionExpiry'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
      branding: data['branding'] ?? {},
    );
  }

  bool get isSubscriptionActive {
    return isActive && subscriptionExpiry.isAfter(DateTime.now());
  }
}

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final String tenantId;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.tenantId,
    required this.isActive,
  });

  bool get canManageProducts =>
      role == UserRole.clientAdmin || role == UserRole.salesInventoryManager;
  bool get canProcessSales =>
      role == UserRole.clientAdmin ||
      role == UserRole.cashier ||
      role == UserRole.salesInventoryManager;
  bool get canManageUsers => role == UserRole.clientAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;
}

// =============================
// PROVIDERS (STATE MANAGEMENT)
// =============================
class AuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  Tenant? _currentTenant;
  bool _isLoading = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  Tenant? get currentTenant => _currentTenant;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      if (!AppUtils.isEmailValid(email)) {
        throw 'Please enter a valid email address';
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);

      await _loadUserData(userCredential.user!.uid);

      // Sync any offline data
      if (_currentTenant != null) {
        await FirebaseService.syncOfflineData(_currentTenant!.id);
      }
    } on FirebaseAuthException catch (e) {
      _error = _handleAuthError(e);
      print('Firebase Auth Error: ${e.code} - ${e.message}');
    } catch (e) {
      _error = 'Login failed: $e';
      print('Login Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // First, check if user is super admin
      final superAdminSnapshot = await FirebaseFirestore.instance
          .collection('super_admins')
          .doc(uid)
          .get();

      if (superAdminSnapshot.exists) {
        _currentUser = AppUser(
          uid: uid,
          email: FirebaseAuth.instance.currentUser!.email!,
          role: UserRole.superAdmin,
          tenantId: 'super_admin',
          isActive: true,
        );
        return;
      }

      // Search for user in tenants
      final tenantsSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .where('isActive', isEqualTo: true)
          .get();

      bool userFound = false;

      for (final tenantDoc in tenantsSnapshot.docs) {
        final userDoc = await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantDoc.id)
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          _currentUser = AppUser(
            uid: uid,
            email: userData['email'],
            role: _parseUserRole(userData['role']),
            tenantId: tenantDoc.id,
            isActive: userData['isActive'] ?? false,
          );

          // Load tenant data
          _currentTenant = Tenant.fromFirestore(tenantDoc);
          userFound = true;
          break;
        }
      }

      if (!userFound) {
        throw Exception('User not found in any active tenant');
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';
      await logout();
      rethrow;
    }
  }

  // Helper method to parse user role from string
  UserRole _parseUserRole(String roleString) {
    switch (roleString) {
      case 'superAdmin':
        return UserRole.superAdmin;
      case 'clientAdmin':
        return UserRole.clientAdmin;
      case 'cashier':
        return UserRole.cashier;
      case 'salesInventoryManager':
        return UserRole.salesInventoryManager;
      default:
        return UserRole.cashier;
    }
  }

  String _extractTenantIdFromPath(String path) {
    // Path format: tenants/{tenantId}/users/{userId}
    final parts = path.split('/');
    if (parts.length >= 2 && parts[0] == 'tenants') {
      return parts[1];
    }
    throw Exception('Invalid user path: $path');
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    _currentTenant = null;
    _error = null;
    notifyListeners();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Login failed: ${e.message}';
    }
  }
}

class TenantProvider with ChangeNotifier {
  final List<Tenant> _tenants = [];
  bool _isLoading = false;
  String? _error;

  List<Tenant> get tenants => _tenants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllTenants() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Loading tenants from Firestore...');

      final snapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .get();

      print('Found ${snapshot.docs.length} tenants');

      _tenants.clear();
      _tenants.addAll(
        snapshot.docs.map((doc) {
          print('Processing tenant: ${doc.id} - ${doc.data()['businessName']}');
          return Tenant.fromFirestore(doc);
        }),
      );

      print('Successfully loaded ${_tenants.length} tenants');
    } catch (e) {
      _error = 'Failed to load tenants: $e';
      print('Error loading tenants: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTenantSubscription(
    String tenantId,
    String plan,
    DateTime expiry,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .update({
            'subscriptionPlan': plan,
            'subscriptionExpiry': expiry,
            'isActive': expiry.isAfter(DateTime.now()),
          });

      // Reload tenants
      await loadAllTenants();
    } catch (e) {
      _error = 'Failed to update subscription: $e';
      notifyListeners();
    }
  }
}

// =============================
// WIDGETS - CORE UI COMPONENTS
// =============================
class MultiTenantSaaSApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TenantProvider()),
      ],
      child: MaterialApp(
        title: 'Multi-Tenant SaaS',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return FutureBuilder<bool>(
      future: _checkSuperAdminExists(),
      builder: (context, snapshot) {
        // Show loading while checking
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen();
        }

        // If no super admin exists, show setup screen
        if (snapshot.hasData && !snapshot.data!) {
          return SuperAdminSetupScreen();
        }

        // Existing auth logic
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return SplashScreen();
            }

            if (userSnapshot.hasData && authProvider.currentUser != null) {
              if (!authProvider.currentUser!.isActive) {
                return AccountDisabledScreen();
              }

              if (authProvider.currentUser!.isSuperAdmin) {
                return SuperAdminDashboard();
              } else {
                return MainPOSScreen();
              }
            }

            return LoginScreen();
          },
        );
      },
    );
  }

  Future<bool> _checkSuperAdminExists() async {
    try {
      return await FirebaseService.checkSuperAdminExists();
    } catch (e) {
      print('Error checking super admin: $e');
      return false;
    }
  }
}

// =============================
// AUTH SCREENS
// =============================
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            Text(
              'Multi-Tenant SaaS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FlutterLogo(size: 80),
                  SizedBox(height: 30),
                  Text(
                    'Welcome Back',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Sign in to your account',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 30),

                  if (authProvider.error != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authProvider.error!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!AppUtils.isEmailValid(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                await authProvider.login(
                                  _emailController.text.trim(),
                                  _passwordController.text,
                                );
                              }
                            },
                      child: authProvider.isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Sign In', style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ClientSignupScreen()),
                    ),
                    child: Text('Don\'t have an account? Sign up here'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountDisabledScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Account Disabled',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Your account has been disabled. Please contact your administrator or check your subscription status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () =>
                    Provider.of<AuthProvider>(context, listen: false).logout(),
                child: Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================
// CLIENT SIGNUP / ONBOARDING
// =============================
class ClientSignupScreen extends StatefulWidget {
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
  List<Map<String, dynamic>> _initialProducts = [];
  List<Map<String, dynamic>> _initialUsers = [];

  final List<Widget> _steps = [];

  @override
  void initState() {
    super.initState();
    _steps.addAll([
      _BusinessInfoStep(_updateBusinessInfo),
      _AdminAccountStep(_updateAdminAccount),
      _SubscriptionStep(_updateSubscription),
      _InitialSetupStep(_updateInitialSetup),
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

  void _updateInitialSetup(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> users,
  ) {
    setState(() {
      _initialProducts = products;
      _initialUsers = users;
    });
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
          _businessName.toLowerCase().replaceAll(' ', '_') +
          '_' +
          DateTime.now().millisecondsSinceEpoch.toString();

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
      for (final user in _initialUsers) {
        await FirebaseService.createUser(
          tenantId: tenantId,
          email: user['email'],
          password: 'temp123', // In production, generate secure temp password
          role: user['role'],
          createdBy: 'system',
        );
      }

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
  _BusinessInfoStep(this.onComplete);

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
  _AdminAccountStep(this.onComplete);

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
  _SubscriptionStep(this.onComplete);

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

class _InitialSetupStep extends StatefulWidget {
  final Function(List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  onComplete;
  _InitialSetupStep(this.onComplete);

  @override
  __InitialSetupStepState createState() => __InitialSetupStepState();
}

class __InitialSetupStepState extends State<_InitialSetupStep> {
  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _users = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.settings, size: 60, color: Colors.purple),
          SizedBox(height: 20),
          Text(
            'Initial Setup',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Set up your initial products and users',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),

          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Products (${_products.length})'),
                      Tab(text: 'Users (${_users.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_buildProductsTab(), _buildUsersTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => widget.onComplete(_products, _users),
            child: Text('Complete Setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _addProduct,
          icon: Icon(Icons.add),
          label: Text('Add Product'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return ListTile(
                title: Text(product['name']),
                subtitle: Text(
                  '\$${product['price']} - Stock: ${product['stock']}',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => setState(() => _products.removeAt(index)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _addUser,
          icon: Icon(Icons.person_add),
          label: Text('Add User'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                title: Text(user['email']),
                subtitle: Text(user['role']),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => setState(() => _users.removeAt(index)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        onSave: (product) => setState(() => _products.add(product)),
      ),
    );
  }

  void _addUser() {
    showDialog(
      context: context,
      builder: (context) =>
          AddUserDialog(onSave: (user) => setState(() => _users.add(user))),
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  final Function(BuildContext) onComplete;
  _ConfirmationStep(this.onComplete);

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

// =============================
// DIALOGS AND MODALS
// =============================
class AddProductDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  AddProductDialog({required this.onSave});

  @override
  _AddProductDialogState createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Product Name'),
            ),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _stockController,
              decoration: InputDecoration(labelText: 'Stock'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveProduct, child: Text('Save')),
      ],
    );
  }

  void _saveProduct() {
    final product = {
      'name': _nameController.text,
      'price': double.parse(_priceController.text),
      'stock': int.parse(_stockController.text),
      'category': _categoryController.text,
      'description': _descriptionController.text,
    };
    widget.onSave(product);
    Navigator.pop(context);
  }
}

class AddUserDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  AddUserDialog({required this.onSave});

  @override
  _AddUserDialogState createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _emailController = TextEditingController();
  String _selectedRole = 'cashier';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 20),
          DropdownButtonFormField(
            value: _selectedRole,
            items: [
              DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              DropdownMenuItem(
                value: 'salesInventoryManager',
                child: Text('Sales & Inventory Manager'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _selectedRole = value.toString()),
            decoration: InputDecoration(labelText: 'Role'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveUser, child: Text('Save')),
      ],
    );
  }

  void _saveUser() {
    final user = {'email': _emailController.text, 'role': _selectedRole};
    widget.onSave(user);
    Navigator.pop(context);
  }
}

// =============================
// TENANT DASHBOARD
// =============================
class TenantDashboard extends StatefulWidget {
  @override
  _TenantDashboardState createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  int _currentIndex = 0;
  int _cartItemCount = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tenant = authProvider.currentTenant;
    final EnhancedCartManager cartManager = EnhancedCartManager();

    if (tenant == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> _clientAdminScreens = [
      DashboardHome(),

      TenantProductsScreen(cartManager: cartManager),
      CartScreen(cartManager: cartManager),
      AnalyticsDashboardScreen(),
      ProductManagementScreen(),

      ReturnsManagementScreen(), // Add this line


      SettingsScreen(),
      if (authProvider.currentUser!.canManageUsers) UsersScreen(),
      TicketsScreen(),

      ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tenant.businessName),
        actions: [
          IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: _clientAdminScreens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex < 5 ? _currentIndex : 4, // Ensure index is within bounds
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
  void _showMoreMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('Manage Inventory'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 4);

                  // Navigate to manage screen
                },
              ),
              ListTile(
                leading: Icon(Icons.assignment_return_outlined),
                title: Text('Returns'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 5);

                  // Navigate to returns screen
                },
              ),
              ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 6);

                  // Navigate to settings screen
                },
              ),
              if (authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Users'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 7);

                    // Navigate to users screen
                  },
                ),
              ListTile(
                leading: Icon(Icons.report_problem),
                title: Text('Ticket'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 8);

                  // Navigate to profile screen
                },
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 9);

                  // Navigate to profile screen
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: FirebaseService.getDashboardStats(
        authProvider.currentUser!.tenantId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final stats = snapshot.data!;

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Stats Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    'Total Revenue',
                    '\$${stats['totalRevenue'].toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                  _StatCard(
                    'Total Sales',
                    stats['totalSales'].toString(),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                  _StatCard(
                    'Total Products',
                    stats['totalProducts'].toString(),
                    Icons.inventory,
                    Colors.orange,
                  ),
                  _StatCard(
                    'Low Stock',
                    stats['lowStockProducts'].toString(),
                    Icons.warning,
                    Colors.red,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Quick Actions
              Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                children: [
                  _ActionCard(
                    'New Sale',
                    Icons.point_of_sale,
                    Colors.blue,
                    () {},
                  ),
                  _ActionCard('Add Product', Icons.add, Colors.green, () {}),
                  if (authProvider.currentUser!.canManageUsers)
                    _ActionCard(
                      'Manage Users',
                      Icons.people,
                      Colors.purple,
                      () {},
                    ),
                  _ActionCard('Support', Icons.support, Colors.orange, () {}),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(title, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ProductsScreen extends StatefulWidget {
  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tenants')
                  .doc(authProvider.currentUser!.tenantId)
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product =
                        products[index].data() as Map<String, dynamic>;

                    if (_searchController.text.isNotEmpty &&
                        !product['name'].toString().toLowerCase().contains(
                          _searchController.text.toLowerCase(),
                        )) {
                      return SizedBox.shrink();
                    }

                    return ProductCard(product: product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          Provider.of<AuthProvider>(context).currentUser!.canManageProducts
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AddProductDialog(
                  onSave: (product) => FirebaseService.addProduct(
                    tenantId: authProvider.currentUser!.tenantId,
                    name: product['name'],
                    price: product['price'],
                    stock: product['stock'],
                    category: product['category'],
                    description: product['description'],
                  ),
                ),
              ),
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.inventory,
          color: product['lowStockAlert'] ? Colors.red : Colors.green,
        ),
        title: Text(product['name']),
        subtitle: Text('\$${product['price']} - Stock: ${product['stock']}'),
        trailing: product['lowStockAlert']
            ? Icon(Icons.warning, color: Colors.red)
            : null,
        onTap: () {
          // Show product details
        },
      ),
    );
  }
}

class SalesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenants')
            .doc(authProvider.currentUser!.tenantId)
            .collection('sales')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final sales = snapshot.data!.docs;

          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.receipt, color: Colors.green),
                  title: Text('Sale #${sale['id']}'),
                  subtitle: Text(
                    '\$${sale['totalAmount']} - ${DateFormat('MMM dd, yyyy').format((sale['createdAt'] as Timestamp).toDate())}',
                  ),
                  trailing: Text(sale['paymentMethod']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton:
          Provider.of<AuthProvider>(context).currentUser!.canProcessSales
          ? FloatingActionButton(
              onPressed: () => _createNewSale(context),
              child: Icon(Icons.point_of_sale),
            )
          : null,
    );
  }

  void _createNewSale(BuildContext context) {
    // Implement POS interface
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Sale'),
        content: Text('POS interface would be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Create the new screen
class SuperAdminManagementScreen extends StatefulWidget {
  @override
  _SuperAdminManagementScreenState createState() =>
      _SuperAdminManagementScreenState();
}

class _SuperAdminManagementScreenState
    extends State<SuperAdminManagementScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  List<Map<String, dynamic>> _superAdmins = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSuperAdmins();
  }

  Future<void> _loadSuperAdmins() async {
    setState(() => _isLoading = true);
    // You'll need to implement this method in SuperAdminSetup class
    _superAdmins = await SuperAdminSetup.getSuperAdmins();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Super Admin Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // Add New Super Admin Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Super Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: InputDecoration(labelText: 'Last Name'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addSuperAdmin,
                      child: Text('Add Super Admin'),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Existing Super Admins
            Text(
              'Existing Super Admins',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            _isLoading
                ? Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: _superAdmins.length,
                      itemBuilder: (context, index) {
                        final admin = _superAdmins[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              Icons.admin_panel_settings,
                              color: Colors.blue,
                            ),
                            title: Text(
                              '${admin['firstName']} ${admin['lastName']}',
                            ),
                            subtitle: Text(admin['email']),
                            trailing: Switch(
                              value: admin['isActive'] ?? false,
                              onChanged: (value) {
                                // Implement activate/deactivate
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSuperAdmin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      await FirebaseService.createSuperAdminUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      // Clear form
      _emailController.clear();
      _passwordController.clear();
      _firstNameController.clear();
      _lastNameController.clear();

      // Reload list
      await _loadSuperAdmins();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Super Admin added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class UsersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenants')
            .doc(authProvider.currentUser!.tenantId)
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text(user['email']),
                  subtitle: Text(user['role']),
                  trailing: Switch(
                    value: user['isActive'] ?? false,
                    onChanged: (value) {
                      // Update user active status
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => AddUserDialog(
            onSave: (user) => FirebaseService.createUser(
              tenantId: authProvider.currentUser!.tenantId,
              email: user['email'],
              password: 'temp123',
              role: user['role'],
              createdBy: authProvider.currentUser!.uid,
            ),
          ),
        ),
        child: Icon(Icons.person_add),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
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

          SizedBox(height: 20),

          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: Icon(Icons.support),
                  title: Text('Support Tickets'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TicketsScreen()),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Branding & Settings'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BrandingScreen()),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.analytics),
                  title: Text('Analytics & Reports'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AnalyticsScreen()),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Notifications'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================
// SUPER ADMIN DASHBOARD
// =============================

// super_admin_setup.dart
// super_admin_setup_screen.dart

class SuperAdminSetupScreen extends StatefulWidget {
  @override
  _SuperAdminSetupScreenState createState() => _SuperAdminSetupScreenState();
}

class _SuperAdminSetupScreenState extends State<SuperAdminSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Icon(
                        Icons.admin_panel_settings,
                        size: 80,
                        color: Colors.blue,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Super Admin Setup',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Create the master administrator account',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 30),

                      // Error Message
                      if (_error != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter first name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter last name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email address';
                          }
                          if (!AppUtils.isEmailValid(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 30),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createSuperAdmin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'Create Super Admin',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),

                      SizedBox(height: 20),
                      Divider(),
                      SizedBox(height: 10),

                      // Information
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Admin Permissions:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('• Manage all tenants and subscriptions'),
                            Text('• Access system-wide analytics'),
                            Text('• Manage support tickets'),
                            Text('• Configure system settings'),
                            Text('• Create additional super admins'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createSuperAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use the FirebaseService to create super admin
      await FirebaseService.createSuperAdminUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Super Admin created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Auto-login the new super admin
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to create super admin: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class SuperAdminSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to create the first super admin
  static Future<void> createSuperAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      print('Starting super admin creation...');

      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User user = userCredential.user!;
      print('Firebase Auth user created: ${user.uid}');

      // Create super admin document
      await _firestore.collection('super_admins').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': 'super_admin',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'permissions': {
          'manage_tenants': true,
          'manage_system': true,
          'view_analytics': true,
          'manage_tickets': true,
        },
      });

      print('Super admin document created successfully!');
      print('Super Admin Details:');
      print('- Email: $email');
      print('- UID: ${user.uid}');
      print('- Name: $firstName $lastName');
    } catch (e) {
      print('Error creating super admin: $e');
      rethrow;
    }
  }

  // Check if any super admin exists
  static Future<bool> hasSuperAdmin() async {
    try {
      final snapshot = await _firestore
          .collection('super_admins')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking super admin: $e');
      return false;
    }
  }

  // Get all super admins (for management)
  static Future<List<Map<String, dynamic>>> getSuperAdmins() async {
    try {
      final snapshot = await _firestore.collection('super_admins').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting super admins: $e');
      return [];
    }
  }
}

class SuperAdminDashboard extends StatefulWidget {
  @override
  _SuperAdminDashboardState createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load tenants when super admin dashboard initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantProvider = Provider.of<TenantProvider>(
        context,
        listen: false,
      );
      tenantProvider.loadAllTenants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _superAdminScreens = [
      /////////
      SuperAdminHome(),
      TenantsManagementScreen(),
      SystemAnalyticsScreen(),
      SuperAdminTicketsScreen(),
      SuperAdminManagementScreen(), // Make sure this is included
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Super Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Refresh tenants list
              final tenantProvider = Provider.of<TenantProvider>(
                context,
                listen: false,
              );
              tenantProvider.loadAllTenants();
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).logout(),
          ),
        ],
      ),
      body: _superAdminScreens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedIconTheme: IconThemeData(color: Colors.black),
        unselectedIconTheme: IconThemeData(color: Colors.grey),
        selectedItemColor: Color(0xff000000),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        unselectedLabelStyle: TextStyle(color: Colors.grey.shade800),
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Tenants'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.support), label: 'Support'),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admins',
          ),
        ],
      ),
    );
  }
}

class TenantsManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    // Load tenants when this screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tenantProvider.tenants.isEmpty) {
        tenantProvider.loadAllTenants();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Tenants Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => tenantProvider.loadAllTenants(),
          ),
        ],
      ),
      body: tenantProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : tenantProvider.tenants.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No Tenants Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'There are no tenants in the system yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => tenantProvider.loadAllTenants(),
                    child: Text('Refresh'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: tenantProvider.tenants.length,
              itemBuilder: (context, index) {
                final tenant = tenantProvider.tenants[index];
                return TenantManagementCard(tenant: tenant);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTenantDialog(context),
        tooltip: 'Create New Tenant',
        child: Icon(Icons.add_business),
      ),
    );
  }

  void _showCreateTenantDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => CreateTenantDialog());
  }
}

class TenantManagementCard extends StatefulWidget {
  final Tenant tenant;
  TenantManagementCard({required this.tenant});

  @override
  _TenantManagementCardState createState() => _TenantManagementCardState();
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _QuickStat(this.label, this.value, this.icon, [this.color = Colors.blue]);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _TenantManagementCardState extends State<TenantManagementCard> {
  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 40,
                  color: widget.tenant.isSubscriptionActive
                      ? Colors.green
                      : Colors.red,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tenant.businessName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('ID: ${widget.tenant.id}'),
                      Text('Plan: ${widget.tenant.subscriptionPlan}'),
                      Text(
                        'Expires: ${DateFormat('MMM dd, yyyy').format(widget.tenant.subscriptionExpiry)}',
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: widget.tenant.isActive,
                      onChanged: (value) {
                        _updateTenantStatus(value);
                      },
                    ),
                    SizedBox(height: 4),
                    widget.tenant.isSubscriptionActive
                        ? Chip(
                            label: Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: Colors.green,
                          )
                        : Chip(
                            label: Text(
                              'Expired',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: Colors.red,
                          ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _renewSubscription(context),
                    icon: Icon(Icons.autorenew),
                    label: Text('Renew'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewDetails(context),
                    icon: Icon(Icons.visibility),
                    label: Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewUsers(context),
                    icon: Icon(Icons.people),
                    label: Text('Users'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateTenantStatus(bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenant.id)
          .update({'isActive': isActive});

      // Reload tenants to reflect the change
      final tenantProvider = Provider.of<TenantProvider>(
        context,
        listen: false,
      );
      await tenantProvider.loadAllTenants();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tenant status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating tenant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _renewSubscription(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RenewSubscriptionDialog(
        tenant: widget.tenant,
        onRenew: (plan, expiry) {
          Provider.of<TenantProvider>(
            context,
            listen: false,
          ).updateTenantSubscription(widget.tenant.id, plan, expiry);
        },
      ),
    );
  }

  void _viewDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TenantDetailsDialog(tenant: widget.tenant),
    );
  }

  void _viewUsers(BuildContext context) {
    // Navigate to tenant users screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.tenant.businessName} - Users'),
        content: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('tenants')
              .doc(widget.tenant.id)
              .collection('users')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error loading users: ${snapshot.error}');
            }

            final users = snapshot.data!.docs;
            return Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(Icons.person),
                    title: Text(user['email']),
                    subtitle: Text(user['role']),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class RenewSubscriptionDialog extends StatefulWidget {
  final Tenant tenant;
  final Function(String, DateTime) onRenew;
  RenewSubscriptionDialog({required this.tenant, required this.onRenew});

  @override
  _RenewSubscriptionDialogState createState() =>
      _RenewSubscriptionDialogState();
}

class _RenewSubscriptionDialogState extends State<RenewSubscriptionDialog> {
  String _selectedPlan = 'monthly';
  DateTime _selectedDate = DateTime.now().add(Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Renew Subscription - ${widget.tenant.businessName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField(
            value: _selectedPlan,
            items: [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (value) =>
                setState(() => _selectedPlan = value.toString()),
            decoration: InputDecoration(labelText: 'Subscription Plan'),
          ),

          SizedBox(height: 16),

          if (_selectedPlan == 'custom')
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: Text(
                'Select Expiry Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final expiry = _selectedPlan == 'monthly'
                ? DateTime.now().add(Duration(days: 30))
                : _selectedPlan == 'yearly'
                ? DateTime.now().add(Duration(days: 365))
                : _selectedDate;

            widget.onRenew(_selectedPlan, expiry);
            Navigator.pop(context);
          },
          child: Text('Renew'),
        ),
      ],
    );
  }
}

class TenantDetailsDialog extends StatelessWidget {
  final Tenant tenant;
  TenantDetailsDialog({required this.tenant});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tenant Details - ${tenant.businessName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow('Business Name', tenant.businessName),
            _DetailRow('Subscription Plan', tenant.subscriptionPlan),
            _DetailRow(
              'Subscription Expiry',
              DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry),
            ),
            _DetailRow(
              'Status',
              tenant.isSubscriptionActive ? 'Active' : 'Expired',
            ),
            _DetailRow(
              'Primary Color',
              tenant.branding['primaryColor'] ?? 'Not set',
            ),
            _DetailRow('Currency', tenant.branding['currency'] ?? 'USD'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class CreateTenantDialog extends StatefulWidget {
  @override
  _CreateTenantDialogState createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<CreateTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedPlan = 'monthly';
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_business, color: Colors.blue),
          SizedBox(width: 10),
          Text('Create New Tenant'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                'Business Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: 'Business Name *',
                  hintText: 'Enter business name',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter business name';
                  }
                  if (value.length < 2) {
                    return 'Business name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              Text(
                'Admin Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _adminEmailController,
                decoration: InputDecoration(
                  labelText: 'Admin Email *',
                  hintText: 'admin@company.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter admin email';
                  }
                  if (!AppUtils.isEmailValid(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _adminPasswordController,
                decoration: InputDecoration(
                  labelText: 'Admin Password *',
                  hintText: 'Enter password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  hintText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm password';
                  }
                  if (value != _adminPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              Text(
                'Subscription Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedPlan,
                decoration: InputDecoration(
                  labelText: 'Subscription Plan *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$29/month',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'yearly',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_month, color: Colors.green),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yearly',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$299/year (Save 15%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPlan = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a subscription plan';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Plan Features
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Includes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildFeature('✓ Unlimited Products'),
                    _buildFeature('✓ Sales Management'),
                    _buildFeature('✓ User Management'),
                    _buildFeature('✓ Analytics Dashboard'),
                    _buildFeature('✓ Support Tickets'),
                    _buildFeature('✓ Custom Branding'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createTenant,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Create Tenant'),
        ),
      ],
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }

  Future<void> _createTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Generate tenant ID
      final tenantId =
          _businessNameController.text.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '_',
          ) +
          '_' +
          DateTime.now().millisecondsSinceEpoch.toString();

      print('Creating tenant: $tenantId');

      // Create the tenant using FirebaseService
      await FirebaseService.createTenant(
        tenantId: tenantId,
        businessName: _businessNameController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
        adminPassword: _adminPasswordController.text,
        subscriptionPlan: _selectedPlan,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Tenant created successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Close dialog
      Navigator.pop(context);

      // Reload tenants list
      final tenantProvider = Provider.of<TenantProvider>(
        context,
        listen: false,
      );
      await tenantProvider.loadAllTenants();
    } catch (e) {
      setState(() {
        _error = 'Failed to create tenant: $e';
      });
      print('Error creating tenant: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}

// =============================
// ADDITIONAL FEATURES
// =============================
class TicketsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Support Tickets')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('tenantId', isEqualTo: authProvider.currentUser!.tenantId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: _getStatusIcon(ticket['status']),
                  title: Text(ticket['subject']),
                  subtitle: Text(ticket['message']),
                  trailing: Chip(
                    label: Text(
                      ticket['status'],
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(ticket['status']),
                  ),
                  onTap: () => _viewTicket(context, tickets[index].id, ticket),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createTicket(context),
        child: Icon(Icons.add),
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icon(Icons.mark_email_unread, color: Colors.orange);
      case 'inProgress':
        return Icon(Icons.hourglass_bottom, color: Colors.blue);
      case 'closed':
        return Icon(Icons.check_circle, color: Colors.green);
      default:
        return Icon(Icons.email);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _createTicket(BuildContext context) {
    showDialog(context: context, builder: (context) => CreateTicketDialog());
  }

  void _viewTicket(
    BuildContext context,
    String ticketId,
    Map<String, dynamic> ticket,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          TicketDetailsDialog(ticketId: ticketId, ticket: ticket),
    );
  }
}

class CreateTicketDialog extends StatefulWidget {
  @override
  _CreateTicketDialogState createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<CreateTicketDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return AlertDialog(
      title: Text('Create Support Ticket'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(labelText: 'Subject'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(labelText: 'Message'),
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            FirebaseService.createTicket(
              tenantId: authProvider.currentUser!.tenantId,
              userId: authProvider.currentUser!.uid,
              subject: _subjectController.text,
              message: _messageController.text,
            );
            Navigator.pop(context);
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}

class TicketDetailsDialog extends StatelessWidget {
  final String ticketId;
  final Map<String, dynamic> ticket;
  TicketDetailsDialog({required this.ticketId, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(ticket['subject']),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ticket['message'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            if (ticket['replies'] != null) ...[
              Text('Replies:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(ticket['replies'] as List)
                  .map(
                    (reply) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('- ${reply['message']}'),
                    ),
                  )
                  .toList(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class SuperAdminTicketsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('All Support Tickets')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: _getStatusIcon(ticket['status']),
                  title: Text(ticket['subject']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticket['message']),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('tenants')
                            .doc(ticket['tenantId'])
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final tenant = Tenant.fromFirestore(snapshot.data!);
                            return Text(
                              'From: ${tenant.businessName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            );
                          }
                          return SizedBox();
                        },
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      ticket['status'],
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(ticket['status']),
                  ),
                  onTap: () =>
                      _manageTicket(context, tickets[index].id, ticket),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icon(Icons.mark_email_unread, color: Colors.orange);
      case 'inProgress':
        return Icon(Icons.hourglass_bottom, color: Colors.blue);
      case 'closed':
        return Icon(Icons.check_circle, color: Colors.green);
      default:
        return Icon(Icons.email);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _manageTicket(
    BuildContext context,
    String ticketId,
    Map<String, dynamic> ticket,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          ManageTicketDialog(ticketId: ticketId, ticket: ticket),
    );
  }
}

class ManageTicketDialog extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticket;
  ManageTicketDialog({required this.ticketId, required this.ticket});

  @override
  _ManageTicketDialogState createState() => _ManageTicketDialogState();
}

class _ManageTicketDialogState extends State<ManageTicketDialog> {
  final _replyController = TextEditingController();
  String _selectedStatus = 'open';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.ticket['status'];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manage Ticket - ${widget.ticket['subject']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.ticket['message'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),

            DropdownButtonFormField(
              value: _selectedStatus,
              items: [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(
                  value: 'inProgress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) =>
                  setState(() => _selectedStatus = value.toString()),
              decoration: InputDecoration(labelText: 'Status'),
            ),

            SizedBox(height: 16),

            TextField(
              controller: _replyController,
              decoration: InputDecoration(labelText: 'Reply Message'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(onPressed: _updateTicket, child: Text('Update')),
      ],
    );
  }

  void _updateTicket() {
    FirebaseService.updateTicket(
      ticketId: widget.ticketId,
      status: _selectedStatus,
      reply: _replyController.text.isNotEmpty ? _replyController.text : null,
    );
    Navigator.pop(context);
  }
}

class BrandingScreen extends StatefulWidget {
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
    final authProvider = context.read<AuthProvider>();
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
    final authProvider = context.read<AuthProvider>();

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
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Analytics & Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getSalesAnalytics(
          authProvider.currentUser!.tenantId,
          DateTime.now().subtract(Duration(days: 30)),
          DateTime.now(),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

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
                ? tenant.businessName.substring(0, 10) + '...'
                : tenant.businessName,
            'value': tenant.isSubscriptionActive ? 1 : 0,
          },
        )
        .toList();
  }
}

class NotificationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

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
    final authProvider = context.read<AuthProvider>();

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
class AppUtils {
  static String formatCurrency(double amount, String currency) {
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  static bool isEmailValid(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}

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
  ErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context) {
    return ErrorWidgetBuilder(child: child);
  }
}

class ErrorWidgetBuilder extends StatefulWidget {
  final Widget child;
  ErrorWidgetBuilder({required this.child});

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
