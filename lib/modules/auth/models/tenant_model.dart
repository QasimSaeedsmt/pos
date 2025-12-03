import 'package:cloud_firestore/cloud_firestore.dart';
// subscription_state.dart
enum SubscriptionState {
  unknown,
  active,
  expiringSoon,
  expired,
  tenantInactive,
}

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
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final subscriptionExpiry = data['subscriptionExpiry'] != null
        ? (data['subscriptionExpiry'] as Timestamp).toDate()
        : DateTime.now().add(Duration(days: 30));

    return Tenant(
      id: doc.id,
      businessName: data['businessName']?.toString() ?? 'Unknown Business',
      subscriptionPlan: data['subscriptionPlan']?.toString() ?? 'monthly',
      subscriptionExpiry: subscriptionExpiry,
      isActive: data['isActive'] ?? false,
      branding: data['branding'] is Map
          ? Map<String, dynamic>.from(data['branding'] as Map)
          : {},
    );
  }

  bool get isSubscriptionActive {
    if (!isActive) return false;
    if (id == 'super_admin') return true;
    return subscriptionExpiry.isAfter(DateTime.now());
  }

  bool get isSubscriptionExpired {
    if (id == 'super_admin') return false;
    return !subscriptionExpiry.isAfter(DateTime.now());
  }

  int get daysUntilExpiry {
    if (id == 'super_admin') return 365;
    return subscriptionExpiry.difference(DateTime.now()).inDays;
  }

  String get subscriptionStatus {
    if (!isActive) return 'Inactive';
    if (isSubscriptionExpired) return 'Expired';
    if (daysUntilExpiry <= 7) return 'Expiring Soon';
    return 'Active';
  }
}