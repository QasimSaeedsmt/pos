import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../modules/auth/models/activity_type.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/auth/screens/login_screen.dart';

enum UserRole { superAdmin, clientAdmin, cashier, salesInventoryManager }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final UserRole role;
  final String tenantId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String createdBy;
  final Map<String, dynamic> profile;
  final List<String> permissions;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    required this.role,
    required this.tenantId,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
    required this.createdBy,
    this.profile = const {},
    this.permissions = const [],
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final email = data['email']?.toString() ?? 'unknown@email.com';
    final displayName = data['displayName']?.toString() ?? email.split('@').first;
    final roleString = data['role']?.toString() ?? 'cashier';
    final role = _parseUserRole(roleString);
    final tenantId = data['tenantId']?.toString() ?? 'unknown_tenant';
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final lastLogin = data['lastLogin'] != null
        ? (data['lastLogin'] as Timestamp).toDate()
        : null;

    return AppUser(
      uid: doc.id,
      email: email,
      displayName: displayName,
      phoneNumber: data['phoneNumber']?.toString(),
      role: role,
      tenantId: tenantId,
      isActive: data['isActive'] ?? false,
      createdAt: createdAt,
      lastLogin: lastLogin,
      createdBy: data['createdBy']?.toString() ?? 'system',
      profile: data['profile'] is Map
          ? Map<String, dynamic>.from(data['profile'] as Map)
          : {},
      permissions: data['permissions'] is List
          ? List<String>.from(data['permissions'] as List)
          : [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role.toString().split('.').last,
      'tenantId': tenantId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdBy': createdBy,
      'profile': profile,
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static UserRole _parseUserRole(String roleString) {
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

  bool get canManageProducts =>
      role == UserRole.clientAdmin || role == UserRole.salesInventoryManager;
  bool get canProcessSales =>
      role == UserRole.clientAdmin ||
          role == UserRole.cashier ||
          role == UserRole.salesInventoryManager;
  bool get canManageUsers => role == UserRole.clientAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;

  String get formattedName =>
      displayName.isNotEmpty ? displayName : email.split('@').first;
}

class UserActivity {
  final String id;
  final String tenantId;
  final String userId;
  final String userEmail;
  final String userDisplayName;
  final String userRole;
  final ActivityType action;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String ipAddress;
  final String userAgent;
  final String module;

  UserActivity({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.userEmail,
    required this.userDisplayName,
    required this.userRole,
    required this.action,
    required this.description,
    this.metadata = const {},
    required this.timestamp,
    this.ipAddress = '',
    this.userAgent = '',
    required this.module,
  });

  factory UserActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserActivity(
      id: doc.id,
      tenantId: data['tenantId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      userDisplayName: data['userDisplayName']?.toString() ?? '',
      userRole: data['userRole']?.toString() ?? '',
      action: _parseActivityType(data['action']?.toString() ?? ''),
      description: data['description']?.toString() ?? '',
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : {},
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      ipAddress: data['ipAddress']?.toString() ?? '',
      userAgent: data['userAgent']?.toString() ?? '',
      module: data['module']?.toString() ?? _getModuleFromAction(data['action']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'userId': userId,
      'userEmail': userEmail,
      'userDisplayName': userDisplayName,
      'userRole': userRole,
      'action': action.toString().split('.').last,
      'description': description,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'module': module,
    };
  }

  static ActivityType _parseActivityType(String type) {
    try {
      return ActivityType.values.firstWhere(
            (e) => e.toString().split('.').last == type,
        orElse: () => ActivityType.user_login,
      );
    } catch (e) {
      return ActivityType.user_login;
    }
  }

  static String _getModuleFromAction(String action) {
    if (action.contains('user_')) return 'user';
    if (action.contains('product_')) return 'product';
    if (action.contains('sale_')) return 'sale';
    if (action.contains('stock_') || action.contains('inventory_')) return 'inventory';
    if (action.contains('customer_')) return 'customer';
    if (action.contains('ticket_')) return 'ticket';
    if (action.contains('payment_')) return 'payment';
    if (action.contains('report_')) return 'report';
    if (action.contains('tenant_') || action.contains('subscription_')) return 'system';
    return 'system';
  }

  IconData get moduleIcon {
    switch (module) {
      case 'user':
        return Icons.person;
      case 'product':
        return Icons.inventory;
      case 'sale':
        return Icons.point_of_sale;
      case 'inventory':
        return Icons.warehouse;
      case 'customer':
        return Icons.people;
      case 'report':
        return Icons.analytics;
      case 'ticket':
        return Icons.support;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.settings;
    }
  }

  Color get moduleColor {
    switch (module) {
      case 'user':
        return Colors.blue;
      case 'product':
        return Colors.purple;
      case 'sale':
        return Colors.green;
      case 'inventory':
        return Colors.orange;
      case 'customer':
        return Colors.teal;
      case 'report':
        return Colors.indigo;
      case 'ticket':
        return Colors.red;
      case 'payment':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class TenantUsersService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> createUserWithDetails({
    required String tenantId,
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String createdBy,
    String? phoneNumber,
    Map<String, dynamic>? profile,
    List<String>? permissions,
  }) async {
    return await _handleFirebaseCall(() async {
      if (password.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      try {
        final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        await userCredential.user!.updateDisplayName(displayName);

        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'email': email.trim(),
          'displayName': displayName,
          'phoneNumber': phoneNumber,
          'role': role,
          'createdBy': createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'tenantId': tenantId,
          'lastLogin': null,
          'profile': profile ?? {},
          'permissions': permissions ?? _getDefaultPermissions(role),
        });

        await logUserActivity(
          tenantId: tenantId,
          userId: userCredential.user!.uid,
          userEmail: email,
          userDisplayName: displayName,
          action: ActivityType.user_created,
          description: 'User account created by $createdBy',
          metadata: {'role': role, 'displayName': displayName},
        );
      } catch (e) {
        if (_auth.currentUser != null && _auth.currentUser!.email == email.trim()) {
          await _auth.currentUser!.delete();
        }
        rethrow;
      }
    });
  }

  static Future<void> updateUserStatus({
    required String tenantId,
    required String userId,
    required bool isActive,
    required String updatedBy,
  }) async {
    return await _handleFirebaseCall(() async {
      final userDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>;

      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(userId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await logUserActivity(
        tenantId: tenantId,
        userId: updatedBy,
        userEmail: userData['email'],
        userDisplayName: userData['displayName'],
        action: isActive ? ActivityType.user_updated : ActivityType.user_deactivated,
        description: 'User ${isActive ? 'activated' : 'deactivated'} by admin',
        metadata: {
          'targetUserId': userId,
          'targetUserEmail': userData['email'],
          'previousStatus': !isActive,
          'newStatus': isActive,
        },
      );
    });
  }

  static Future<void> updateUserProfile({
    required String tenantId,
    required String userId,
    required String displayName,
    required String? phoneNumber,
    required String role,
    required String updatedBy,
  }) async {
    return await _handleFirebaseCall(() async {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(userId)
          .update({
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await logUserActivity(
        tenantId: tenantId,
        userId: updatedBy,
        userEmail: '',
        userDisplayName: '',
        action: ActivityType.user_updated,
        description: 'User profile updated by admin',
        metadata: {
          'targetUserId': userId,
          'displayName': displayName,
          'role': role,
        },
      );
    });
  }

  static Future<void> resetUserPassword({
    required String email,
    required String updatedBy,
    required String tenantId,
  }) async {
    return await _handleFirebaseCall(() async {
      await _auth.sendPasswordResetEmail(email: email.trim());

      await logUserActivity(
        tenantId: tenantId,
        userId: updatedBy,
        userEmail: '',
        userDisplayName: '',
        action: ActivityType.user_password_changed,
        description: 'Password reset email sent to $email',
        metadata: {'targetEmail': email},
      );
    });
  }

  static Future<void> deleteUser({
    required String tenantId,
    required String userId,
    required String deletedBy,
  }) async {
    return await _handleFirebaseCall(() async {
      final userDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>;

      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(userId)
          .delete();

      await logUserActivity(
        tenantId: tenantId,
        userId: deletedBy,
        userEmail: userData['email'],
        userDisplayName: userData['displayName'],
        action: ActivityType.user_deactivated,
        description: 'User deleted by admin',
        metadata: {
          'targetUserId': userId,
          'targetUserEmail': userData['email'],
        },
      );
    });
  }

  static Future<void> logUserActivity({
    required String tenantId,
    required String userId,
    required String userEmail,
    required String userDisplayName,
    required ActivityType action,
    required String description,
    Map<String, dynamic> metadata = const {},
    String ipAddress = '',
    String userAgent = '',
  }) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('user_activities')
          .add({
        'tenantId': tenantId,
        'userId': userId,
        'userEmail': userEmail,
        'userDisplayName': userDisplayName,
        'action': action.toString().split('.').last,
        'description': description,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'module': UserActivity._getModuleFromAction(action.toString().split('.').last),
      });
    } catch (e) {
      print('Failed to log activity: $e');
    }
  }

  static List<String> _getDefaultPermissions(String role) {
    switch (role) {
      case 'clientAdmin':
        return ['manage_users', 'manage_products', 'view_reports', 'manage_sales'];
      case 'salesInventoryManager':
        return ['manage_products', 'view_reports', 'manage_sales'];
      case 'cashier':
        return ['process_sales', 'view_products'];
      default:
        return ['view_products'];
    }
  }

  static Stream<QuerySnapshot> getUserActivities(
      String tenantId, {
        String? userId,
        int limit = 50,
      }) {
    Query query = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('user_activities')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots();
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
}

class EnhancedAddUserDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const EnhancedAddUserDialog({super.key, required this.onSave});

  @override
  _EnhancedAddUserDialogState createState() => _EnhancedAddUserDialogState();
}

class _EnhancedAddUserDialogState extends State<EnhancedAddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'cashier';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue),
          SizedBox(width: 8),
          Text('Add New User'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Display Name *',
                  hintText: 'Enter full name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter display name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'user@company.com',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1234567890',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Enter temporary password',
                  prefixIcon: Icon(Icons.lock),
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
              SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  hintText: 'Confirm temporary password',
                  prefixIcon: Icon(Icons.lock_outline),
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
              SizedBox(height: 16),
              DropdownButtonFormField(
                value: _selectedRole,
                items: [
                  DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                  DropdownMenuItem(
                    value: 'salesInventoryManager',
                    child: Text('Sales & Inventory Manager'),
                  ),
                  DropdownMenuItem(
                    value: 'clientAdmin',
                    child: Text('Client Admin'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value.toString();
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.assignment_ind),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a role';
                  }
                  return null;
                },
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
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading
              ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Create User'),
        ),
      ],
    );
  }

  void _saveUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final userData = {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'displayName': _displayNameController.text.trim(),
          'role': _selectedRole,
          'phoneNumber': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        };

        await widget.onSave(userData);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class EditUserDialog extends StatefulWidget {
  final AppUser user;
  const EditUserDialog({super.key, required this.user});

  @override
  _EditUserDialogState createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'cashier';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.user.displayName;
    _phoneController.text = widget.user.phoneNumber ?? '';
    _selectedRole = widget.user.role.toString().split('.').last;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue),
          SizedBox(width: 8),
          Text('Edit User'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Display Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter display name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField(
                value: _selectedRole,
                items: [
                  DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                  DropdownMenuItem(
                    value: 'salesInventoryManager',
                    child: Text('Sales & Inventory Manager'),
                  ),
                  DropdownMenuItem(
                    value: 'clientAdmin',
                    child: Text('Client Admin'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value.toString();
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.assignment_ind),
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
          onPressed: _isLoading ? null : _updateUser,
          child: _isLoading
              ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Update User'),
        ),
      ],
    );
  }

  void _updateUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authProvider = Provider.of<MyAuthProvider>(context, listen: false);

        await TenantUsersService.updateUserProfile(
          tenantId: authProvider.currentUser!.tenantId,
          userId: widget.user.uid,
          displayName: _displayNameController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          role: _selectedRole,
          updatedBy: authProvider.currentUser!.uid,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class ResetPasswordDialog extends StatelessWidget {
  final AppUser user;
  const ResetPasswordDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_reset, color: Colors.orange),
          SizedBox(width: 8),
          Text('Reset Password'),
        ],
      ),
      content: Text(
        'This will send a password reset email to ${user.email}. '
            'They will be able to set a new password using the link in the email.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await TenantUsersService.resetUserPassword(
                email: user.email,
                updatedBy: authProvider.currentUser!.uid,
                tenantId: authProvider.currentUser!.tenantId,
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password reset email sent successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error sending reset email: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: Text('Send Reset Email'),
        ),
      ],
    );
  }
}

class EnhancedUsersScreen extends StatelessWidget {
  const EnhancedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('User Management'),
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.history), text: 'Activity Log'),
            ],
          ),
        ),
        body: TabBarView(children: [_UsersListTab(), _ActivityLogTab()]),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddUserDialog(context),
          child: Icon(Icons.person_add),
          tooltip: 'Add New User',
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EnhancedAddUserDialog(
        onSave: (userData) async {
          final authProvider = context.read<MyAuthProvider>();
          await TenantUsersService.createUserWithDetails(
            tenantId: authProvider.currentUser!.tenantId,
            email: userData['email'],
            password: userData['password'],
            displayName: userData['displayName'],
            role: userData['role'],
            createdBy: authProvider.currentUser!.uid,
            phoneNumber: userData['phoneNumber'],
          );
        },
      ),
    );
  }
}

class _UsersListTab extends StatelessWidget {
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.red;
      case UserRole.clientAdmin:
        return Colors.blue;
      case UserRole.salesInventoryManager:
        return Colors.purple;
      case UserRole.cashier:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _toggleUserStatus(BuildContext context, AppUser user, bool isActive) async {
    final authProvider = context.read<MyAuthProvider>();

    try {
      await TenantUsersService.updateUserStatus(
        tenantId: authProvider.currentUser!.tenantId,
        userId: user.uid,
        isActive: isActive,
        updatedBy: authProvider.currentUser!.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${isActive ? 'activated' : 'deactivated'} successfully'),
          backgroundColor: isActive ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editUser(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );
  }

  void _viewUserActivity(BuildContext context, AppUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserActivityScreen(user: user)),
    );
  }

  void _resetPassword(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => ResetPasswordDialog(user: user),
    );
  }

  void _deleteUser(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${user.formattedName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<MyAuthProvider>();
                await TenantUsersService.deleteUser(
                  tenantId: authProvider.currentUser!.tenantId,
                  userId: user.uid,
                  deletedBy: authProvider.currentUser!.uid,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenants')
          .doc(authProvider.currentUser!.tenantId)
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Users Found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Add your first user to get started',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final user = AppUser.fromFirestore(userDoc);

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading:                     Switch(
                  value: user.isActive,
                  onChanged: (value) => _toggleUserStatus(context, user, value),
                ),

                title: Text(
                  user.formattedName,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            user.role.toString().split('.').last,
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: _getRoleColor(user.role),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (user.phoneNumber != null) ...[
                          SizedBox(width: 8),
                          Icon(Icons.phone, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.phoneNumber!,
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (user.lastLogin != null)
                      Text(
                        'Last login: ${DateFormat('MMM dd, yyyy HH:mm').format(user.lastLogin!)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton(
                      icon: Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit User'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'activity',
                          child: Row(
                            children: [
                              Icon(Icons.history, size: 18),
                              SizedBox(width: 8),
                              Text('View Activity'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'password',
                          child: Row(
                            children: [
                              Icon(Icons.lock_reset, size: 18),
                              SizedBox(width: 8),
                              Text('Reset Password'),
                            ],
                          ),
                        ),
                        if (!user.isActive)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete User',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editUser(context, user);
                            break;
                          case 'activity':
                            _viewUserActivity(context, user);
                            break;
                          case 'password':
                            _resetPassword(context, user);
                            break;
                          case 'delete':
                            _deleteUser(context, user);
                            break;
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityLogTab extends StatelessWidget {
  Color _getActivityColor(ActivityType action) {
    switch (action) {
      case ActivityType.user_login:
      case ActivityType.sale_created:
      case ActivityType.payment_processed:
        return Colors.green;
      case ActivityType.user_created:
      case ActivityType.product_created:
        return Colors.blue;
      case ActivityType.user_deactivated:
      case ActivityType.sale_deleted:
      case ActivityType.payment_failed:
        return Colors.red;
      case ActivityType.user_updated:
      case ActivityType.product_updated:
      case ActivityType.sale_updated:
        return Colors.orange;
      case ActivityType.low_stock_alert:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  List<Widget> _buildMetadataWidgets(Map<String, dynamic> metadata) {
    return metadata.entries.map((entry) {
      return Text(
        '${entry.key}: ${entry.value}',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      );
    }).toList();
  }

  void _showActivityDetails(BuildContext context, UserActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(activity.moduleIcon, color: activity.moduleColor),
            SizedBox(width: 8),
            Text('Activity Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Action',
                activity.action.toString().split('.').last.replaceAll('_', ' '),
              ),
              _buildDetailRow('Description', activity.description),
              _buildDetailRow(
                'User',
                '${activity.userDisplayName} (${activity.userEmail})',
              ),
              _buildDetailRow('Role', activity.userRole),
              _buildDetailRow('Module', activity.module),
              _buildDetailRow(
                'Time',
                DateFormat('MMM dd, yyyy HH:mm:ss').format(activity.timestamp),
              ),
              if (activity.metadata.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...activity.metadata.entries.map(
                      (entry) => _buildDetailRow(entry.key, entry.value.toString()),
                ),
              ],
              if (activity.ipAddress.isNotEmpty)
                _buildDetailRow('IP Address', activity.ipAddress),
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: TenantUsersService.getUserActivities(
        authProvider.currentUser!.tenantId,
        limit: 100,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final activities = snapshot.data!.docs;

        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Activities Yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'User activities will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = UserActivity.fromFirestore(activities[index]);

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activity.moduleColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activity.moduleIcon,
                    color: activity.moduleColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  activity.description,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activity.userDisplayName} • ${DateFormat('MMM dd, yyyy HH:mm').format(activity.timestamp)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (activity.metadata.isNotEmpty) ...[
                      SizedBox(height: 4),
                      ..._buildMetadataWidgets(activity.metadata),
                    ],
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    activity.action.toString().split('.').last.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: _getActivityColor(activity.action),
                ),
                onTap: () => _showActivityDetails(context, activity),
              ),
            );
          },
        );
      },
    );
  }
}

class UserActivityScreen extends StatefulWidget {
  final AppUser user;
  const UserActivityScreen({super.key, required this.user});

  @override
  _UserActivityScreenState createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  String _selectedFilter = 'all';
  final List<String> _filters = [
    'all',
    'user',
    'product',
    'sale',
    'inventory',
    'ticket',
    'report',
    'system',
  ];

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'user':
        return Icons.person;
      case 'product':
        return Icons.inventory;
      case 'sale':
        return Icons.point_of_sale;
      case 'inventory':
        return Icons.warehouse;
      case 'ticket':
        return Icons.support;
      case 'report':
        return Icons.analytics;
      case 'system':
        return Icons.settings;
      default:
        return Icons.all_inclusive;
    }
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'user':
        return Colors.blue;
      case 'product':
        return Colors.purple;
      case 'sale':
        return Colors.green;
      case 'inventory':
        return Colors.orange;
      case 'ticket':
        return Colors.red;
      case 'report':
        return Colors.indigo;
      case 'system':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getActivityColor(ActivityType action) {
    switch (action) {
      case ActivityType.user_login:
      case ActivityType.sale_created:
      case ActivityType.payment_processed:
        return Colors.green;
      case ActivityType.user_created:
      case ActivityType.product_created:
        return Colors.blue;
      case ActivityType.user_deactivated:
      case ActivityType.sale_deleted:
      case ActivityType.payment_failed:
        return Colors.red;
      case ActivityType.user_updated:
      case ActivityType.product_updated:
      case ActivityType.sale_updated:
        return Colors.orange;
      case ActivityType.low_stock_alert:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  List<Widget> _buildMetadataWidgets(Map<String, dynamic> metadata) {
    return metadata.entries.map((entry) {
      return Text(
        '${entry.key}: ${entry.value}',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      );
    }).toList();
  }

  void _showActivityDetails(BuildContext context, UserActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(activity.moduleIcon, color: activity.moduleColor),
            SizedBox(width: 8),
            Text('Activity Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Action',
                activity.action.toString().split('.').last.replaceAll('_', ' '),
              ),
              _buildDetailRow('Description', activity.description),
              _buildDetailRow(
                'User',
                '${activity.userDisplayName} (${activity.userEmail})',
              ),
              _buildDetailRow('Role', activity.userRole),
              _buildDetailRow('Module', activity.module),
              _buildDetailRow(
                'Time',
                DateFormat('MMM dd, yyyy HH:mm:ss').format(activity.timestamp),
              ),
              if (activity.metadata.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...activity.metadata.entries.map(
                      (entry) => _buildDetailRow(entry.key, entry.value.toString()),
                ),
              ],
              if (activity.ipAddress.isNotEmpty)
                _buildDetailRow('IP Address', activity.ipAddress),
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.formattedName} - Activity'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (BuildContext context) {
              return _filters.map((String filter) {
                return PopupMenuItem<String>(
                  value: filter,
                  child: Row(
                    children: [
                      Icon(_getFilterIcon(filter), color: _getFilterColor(filter)),
                      SizedBox(width: 8),
                      Text(filter.toUpperCase()),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.map((filter) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(filter.toUpperCase()),
                    selected: _selectedFilter == filter,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedFilter = selected ? filter : 'all';
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: _getFilterColor(filter),
                    labelStyle: TextStyle(
                      color: _selectedFilter == filter ? Colors.white : Colors.black,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: TenantUsersService.getUserActivities(
                authProvider.currentUser!.tenantId,
                userId: widget.user.uid,
                limit: 100,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final activities = snapshot.data!.docs;
                final filteredActivities = activities.where((doc) {
                  if (_selectedFilter == 'all') return true;
                  final activity = UserActivity.fromFirestore(doc);
                  return activity.module == _selectedFilter;
                }).toList();

                if (filteredActivities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No activities found'),
                        Text(
                          _selectedFilter == 'all'
                              ? 'This user has no activities yet'
                              : 'No ${_selectedFilter} activities found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredActivities.length,
                  itemBuilder: (context, index) {
                    final activity = UserActivity.fromFirestore(filteredActivities[index]);

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: activity.moduleColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activity.moduleIcon,
                            color: activity.moduleColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          activity.description,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'By ${activity.userDisplayName} • ${DateFormat('MMM dd, yyyy HH:mm').format(activity.timestamp)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (activity.metadata.isNotEmpty) ...[
                              SizedBox(height: 4),
                              ..._buildMetadataWidgets(activity.metadata),
                            ],
                          ],
                        ),
                        trailing: Chip(
                          label: Text(
                            activity.action.toString().split('.').last.replaceAll('_', ' '),
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: _getActivityColor(activity.action),
                        ),
                        onTap: () => _showActivityDetails(context, activity),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EnhancedProfileScreen extends StatelessWidget {
  const EnhancedProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final user = authProvider.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EditUserDialog(user: user),
              );
            },
          ),
        ],
      ),
      body: Padding(
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
                      backgroundColor: Colors.blue,
                      child: Text(
                        user.formattedName[0].toUpperCase(),
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      user.formattedName,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(user.email),
                    if (user.phoneNumber != null) Text(user.phoneNumber!),
                    SizedBox(height: 8),
                    Chip(
                      label: Text(
                        user.role.toString().split('.').last,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                    SizedBox(height: 16),
                    if (user.lastLogin != null)
                      Text(
                        'Last login: ${DateFormat('MMM dd, yyyy HH:mm').format(user.lastLogin!)}',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.history),
                          title: Text('View My Activity'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserActivityScreen(user: user),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.lock_reset),
                          title: Text('Change Password'),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ResetPasswordDialog(user: user),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.red),
                          title: Text('Logout', style: TextStyle(color: Colors.red)),
                          onTap: (){
                            authProvider.logout();
    Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => LoginScreen()),
    );
    } ,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}