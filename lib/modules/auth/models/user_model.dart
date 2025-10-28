// import 'package:cloud_firestore/cloud_firestore.dart';
//
// enum UserRole { superAdmin, clientAdmin, cashier, salesInventoryManager }
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
//     final email = data['email']?.toString() ?? 'unknown@email.com';
//     final displayName = data['displayName']?.toString() ?? email.split('@').first;
//     final roleString = data['role']?.toString() ?? 'cashier';
//     final role = _parseUserRole(roleString);
//     final tenantId = data['tenantId']?.toString() ?? 'unknown_tenant';
//     final createdAt = data['createdAt'] != null
//         ? (data['createdAt'] as Timestamp).toDate()
//         : DateTime.now();
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
//       profile: data['profile'] is Map
//           ? Map<String, dynamic>.from(data['profile'] as Map)
//           : {},
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
//         return UserRole.cashier;
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
//   String get formattedName =>
//       displayName.isNotEmpty ? displayName : email.split('@').first;
// }