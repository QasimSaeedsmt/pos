import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/tenant_model.dart';

class AuthRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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

  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handlePasswordResetError(e);
    } catch (e) {
      throw 'Failed to send reset email. Please try again.';
    }
  }

  static String _handlePasswordResetError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Failed to send reset email: ${e.message}';
    }
  }

  static Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw _handlePasswordResetError(e);
    }
  }

  static Future<void> verifyPasswordResetCode(String code) async {
    try {
      await _auth.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (e) {
      throw 'Invalid or expired reset code. Please request a new one. Details: $e';
    }
  }

  static Future<AppUser?> loadUserData(String uid) async {
    try {
      final superAdminDoc = await _firestore
          .collection('super_admins')
          .doc(uid)
          .get();

      if (superAdminDoc.exists) {
        final data = superAdminDoc.data() ?? {};
        return AppUser(
          uid: uid,
          email: _auth.currentUser?.email ?? 'unknown@email.com',
          displayName: '${data['firstName'] ?? 'Admin'} ${data['lastName'] ?? ''}'.trim(),
          role: UserRole.superAdmin,
          tenantId: 'super_admin',
          isActive: data['isActive'] ?? true,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          createdBy: data['createdBy'] ?? 'system',
          lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
        );
      }

      final tenantsSnap = await _firestore
          .collection('tenants')
          .where('isActive', isEqualTo: true)
          .get();

      for (final tenantDoc in tenantsSnap.docs) {
        final userDoc = await tenantDoc.reference
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          return AppUser.fromFirestore(userDoc);
        }
      }

      return null;
    } catch (e) {
      throw 'Failed to load user data: $e';
    }
  }

  static Future<Tenant?> loadTenantData(String tenantId) async {
    try {
      if (tenantId == 'super_admin') {
        return Tenant(
          id: 'super_admin',
          businessName: 'Super Admin Portal',
          subscriptionPlan: 'enterprise',
          subscriptionExpiry: DateTime.now().add(Duration(days: 365)),
          isActive: true,
          branding: {},
        );
      }

      final tenantDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (tenantDoc.exists) {
        return Tenant.fromFirestore(tenantDoc);
      }

      return null;
    } catch (e) {
      throw 'Failed to load tenant data: $e';
    }
  }
}