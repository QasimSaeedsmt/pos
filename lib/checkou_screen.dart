
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'main.dart';
//
// enum ActivityType {
//   // Keep all existing types
//   user_login,
//   user_logout,
//   user_created,
//   user_updated,
//   user_deactivated,
//   sale_created,
//   sale_updated,
//   sale_deleted,
//   product_created,
//   product_updated,
//   product_deleted,
//   stock_updated,
//   tenant_created,
//   tenant_updated,
//   subscription_updated,
//   ticket_created,
//   ticket_updated,
//   payment_processed,
//   report_generated,
//
//   // Add new types for comprehensive tracking
//   user_password_changed,
//   user_profile_updated,
//   product_stock_updated,
//   product_category_created,
//   product_category_updated,
//   sale_refunded,
//   sale_cancelled,
//   inventory_checked,
//   inventory_adjusted,
//   low_stock_alert,
//   customer_created,
//   customer_updated,
//   customer_deleted,
//   report_exported,
//   settings_updated,
//   branding_updated,
//   ticket_closed,
//   ticket_replied,
//   payment_failed,
//   payment_refunded,
// }
// class Tenant {
//   final String id;
//   final String businessName;
//   final String subscriptionPlan;
//   final DateTime subscriptionExpiry;
//   final bool isActive;
//   final Map<String, dynamic> branding;
//
//   Tenant({
//     required this.id,
//     required this.businessName,
//     required this.subscriptionPlan,
//     required this.subscriptionExpiry,
//     required this.isActive,
//     required this.branding,
//   });
//
//   factory Tenant.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>? ?? {};
//
//     // Calculate expiry date with fallback
//     final subscriptionExpiry = data['subscriptionExpiry'] != null
//         ? (data['subscriptionExpiry'] as Timestamp).toDate()
//         : DateTime.now().add(Duration(days: 30)); // Default 30 days
//
//     return Tenant(
//       id: doc.id,
//       businessName: data['businessName']?.toString() ?? 'Unknown Business',
//       subscriptionPlan: data['subscriptionPlan']?.toString() ?? 'monthly',
//       subscriptionExpiry: subscriptionExpiry,
//       isActive: data['isActive'] ?? false,
//       branding: data['branding'] is Map
//           ? Map<String, dynamic>.from(data['branding'] as Map)
//           : {},
//     );
//   }
//
//   bool get isSubscriptionActive {
//     return isActive && subscriptionExpiry.isAfter(DateTime.now());
//   }
// }
//
//
// class AppUser {
//   final String uid;
//   final String email;
//   final String displayName;
//   final String? phoneNumber;
//   final UserRole role;
//   final String tenantId;
//   final bool isActive;
//   final DateTime createdAt;
//   final DateTime? lastLogin;
//   final String createdBy;
//   final Map<String, dynamic> profile;
//   final List<String> permissions;
//
//   AppUser({
//     required this.uid,
//     required this.email,
//     required this.displayName,
//     this.phoneNumber,
//     required this.role,
//     required this.tenantId,
//     required this.isActive,
//     required this.createdAt,
//     this.lastLogin,
//     required this.createdBy,
//     this.profile = const {},
//     this.permissions = const [],
//   });
//
//   factory AppUser.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>? ?? {};
//
//     // Extract email with fallback
//     final email = data['email']?.toString() ?? 'unknown@email.com';
//
//     // Extract display name with fallback
//     final displayName = data['displayName']?.toString() ??
//         email.split('@').first ??
//         'User';
//
//     // Parse role with fallback
//     final roleString = data['role']?.toString() ?? 'cashier';
//     final role = _parseUserRole(roleString);
//
//     // Extract tenant ID with fallback
//     final tenantId = data['tenantId']?.toString() ?? 'unknown_tenant';
//
//     // Parse dates with fallbacks
//     final createdAt = data['createdAt'] != null
//         ? (data['createdAt'] as Timestamp).toDate()
//         : DateTime.now();
//
//     final lastLogin = data['lastLogin'] != null
//         ? (data['lastLogin'] as Timestamp).toDate()
//         : null;
//
//     return AppUser(
//       uid: doc.id,
//       email: email,
//       displayName: displayName,
//       phoneNumber: data['phoneNumber']?.toString(),
//       role: role,
//       tenantId: tenantId,
//       isActive: data['isActive'] ?? false,
//       createdAt: createdAt,
//       lastLogin: lastLogin,
//       createdBy: data['createdBy']?.toString() ?? 'system',
//       profile: data['profile'] is Map ? Map<String, dynamic>.from(data['profile'] as Map) : {},
//       permissions: data['permissions'] is List
//           ? List<String>.from(data['permissions'] as List)
//           : [],
//     );
//   }
//
//   Map<String, dynamic> toFirestore() {
//     return {
//       'uid': uid,
//       'email': email,
//       'displayName': displayName,
//       'phoneNumber': phoneNumber,
//       'role': role.toString().split('.').last,
//       'tenantId': tenantId,
//       'isActive': isActive,
//       'createdAt': Timestamp.fromDate(createdAt),
//       'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
//       'createdBy': createdBy,
//       'profile': profile,
//       'permissions': permissions,
//       'updatedAt': FieldValue.serverTimestamp(),
//     };
//   }
//
//   static UserRole _parseUserRole(String roleString) {
//     switch (roleString) {
//       case 'superAdmin':
//         return UserRole.superAdmin;
//       case 'clientAdmin':
//         return UserRole.clientAdmin;
//       case 'cashier':
//         return UserRole.cashier;
//       case 'salesInventoryManager':
//         return UserRole.salesInventoryManager;
//       default:
//         return UserRole.cashier; // Default fallback
//     }
//   }
//
//   bool get canManageProducts =>
//       role == UserRole.clientAdmin || role == UserRole.salesInventoryManager;
//   bool get canProcessSales =>
//       role == UserRole.clientAdmin ||
//           role == UserRole.cashier ||
//           role == UserRole.salesInventoryManager;
//   bool get canManageUsers => role == UserRole.clientAdmin;
//   bool get isSuperAdmin => role == UserRole.superAdmin;
//
//   String get formattedName => displayName.isNotEmpty ? displayName : email.split('@').first;
// }
// class UserActivity {
//   final String id;
//   final String tenantId;
//   final String userId;
//   final String userEmail;
//   final String userDisplayName;
//   final String userRole;
//   final ActivityType action;
//   final String description;
//   final Map<String, dynamic> metadata;
//   final DateTime timestamp;
//   final String ipAddress;
//   final String userAgent;
//   final String module; // New field to categorize activities
//
//   UserActivity({
//     required this.id,
//     required this.tenantId,
//     required this.userId,
//     required this.userEmail,
//     required this.userDisplayName,
//     required this.userRole,
//     required this.action,
//     required this.description,
//     this.metadata = const {},
//     required this.timestamp,
//     this.ipAddress = '',
//     this.userAgent = '',
//     required this.module,
//   });
//
//   factory UserActivity.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>? ?? {};
//
//     return UserActivity(
//       id: doc.id,
//       tenantId: data['tenantId']?.toString() ?? '',
//       userId: data['userId']?.toString() ?? '',
//       userEmail: data['userEmail']?.toString() ?? '',
//       userDisplayName: data['userDisplayName']?.toString() ?? '',
//       userRole: data['userRole']?.toString() ?? '',
//       action: _parseActivityType(data['action']?.toString() ?? ''),
//       description: data['description']?.toString() ?? '',
//       metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata'] as Map) : {},
//       timestamp: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now(),
//       ipAddress: data['ipAddress']?.toString() ?? '',
//       userAgent: data['userAgent']?.toString() ?? '',
//       module: data['module']?.toString() ?? _getModuleFromAction(data['action']?.toString() ?? ''),
//     );
//   }
//
//   Map<String, dynamic> toFirestore() {
//     return {
//       'tenantId': tenantId,
//       'userId': userId,
//       'userEmail': userEmail,
//       'userDisplayName': userDisplayName,
//       'userRole': userRole,
//       'action': action.toString().split('.').last,
//       'description': description,
//       'metadata': metadata,
//       'timestamp': Timestamp.fromDate(timestamp),
//       'ipAddress': ipAddress,
//       'userAgent': userAgent,
//       'module': module,
//     };
//   }
//
//   static ActivityType _parseActivityType(String type) {
//     try {
//       return ActivityType.values.firstWhere(
//             (e) => e.toString().split('.').last == type,
//         orElse: () => ActivityType.user_login,
//       );
//     } catch (e) {
//       return ActivityType.user_login;
//     }
//   }
//
//   static String _getModuleFromAction(String action) {
//     if (action.contains('user_')) return 'user';
//     if (action.contains('product_')) return 'product';
//     if (action.contains('sale_')) return 'sale';
//     if (action.contains('stock_') || action.contains('inventory_')) return 'inventory';
//     if (action.contains('customer_')) return 'customer';
//     if (action.contains('ticket_')) return 'ticket';
//     if (action.contains('payment_')) return 'payment';
//     if (action.contains('report_')) return 'report';
//     if (action.contains('tenant_') || action.contains('subscription_')) return 'system';
//     return 'system';
//   }
//
//   // Helper method to get module icon
//   IconData get moduleIcon {
//     switch (module) {
//       case 'user':
//         return Icons.person;
//       case 'product':
//         return Icons.inventory;
//       case 'sale':
//         return Icons.point_of_sale;
//       case 'inventory':
//         return Icons.warehouse;
//       case 'customer':
//         return Icons.people;
//       case 'report':
//         return Icons.analytics;
//       case 'ticket':
//         return Icons.support;
//       case 'payment':
//         return Icons.payment;
//       default:
//         return Icons.settings;
//     }
//   }
//
//   // Helper method to get module color
//   Color get moduleColor {
//     switch (module) {
//       case 'user':
//         return Colors.blue;
//       case 'product':
//         return Colors.purple;
//       case 'sale':
//         return Colors.green;
//       case 'inventory':
//         return Colors.orange;
//       case 'customer':
//         return Colors.teal;
//       case 'report':
//         return Colors.indigo;
//       case 'ticket':
//         return Colors.red;
//       case 'payment':
//         return Colors.green;
//       default:
//         return Colors.grey;
//     }
//   }
// }
// enum UserRole { superAdmin, clientAdmin, cashier, salesInventoryManager }
