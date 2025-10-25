import 'package:cloud_firestore/cloud_firestore.dart';

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
    return isActive && subscriptionExpiry.isAfter(DateTime.now());
  }
}