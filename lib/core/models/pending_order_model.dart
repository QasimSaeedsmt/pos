// pending_order_model.dart
import 'package:hive/hive.dart';
import 'package:mpcm/core/models/cart_item_model.dart';
import 'package:mpcm/core/models/customer_model.dart';

part 'pending_order_model.g.dart';

@HiveType(typeId: 14)
class PendingOrder {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final Map<String, dynamic> orderData;

  @HiveField(2)
  final Map<String, dynamic>? customerData;

  @HiveField(3)
  final Map<String, dynamic> paymentData;

  @HiveField(4)
  final Map<String, dynamic> discountSummary;

  @HiveField(5)
  final Map<String, dynamic> settingsUsed;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final String syncStatus;

  @HiveField(8)
  final int syncAttempts;

  @HiveField(9)
  final String version;

  @HiveField(10)
  final Map<String, dynamic>? additionalData;

  PendingOrder({
    required this.id,
    required this.orderData,
    this.customerData,
    required this.paymentData,
    required this.discountSummary,
    required this.settingsUsed,
    required this.createdAt,
    required this.syncStatus,
    required this.syncAttempts,
    required this.version,
    this.additionalData,
  });

  factory PendingOrder.fromJson(Map<String, dynamic> json) {
    return PendingOrder(
      id: json['id'] as int,
      orderData: Map<String, dynamic>.from(json['order_data']),
      customerData: json['customer_data'] != null
          ? Map<String, dynamic>.from(json['customer_data'])
          : null,
      paymentData: Map<String, dynamic>.from(json['payment_data']),
      discountSummary: Map<String, dynamic>.from(json['discount_summary']),
      settingsUsed: Map<String, dynamic>.from(json['settings_used']),
      createdAt: DateTime.parse(json['created_at']),
      syncStatus: json['sync_status'] as String,
      syncAttempts: json['sync_attempts'] as int,
      version: json['version'] as String,
      additionalData: json['additional_data'] != null
          ? Map<String, dynamic>.from(json['additional_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_data': orderData,
      'customer_data': customerData,
      'payment_data': paymentData,
      'discount_summary': discountSummary,
      'settings_used': settingsUsed,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus,
      'sync_attempts': syncAttempts,
      'version': version,
      'additional_data': additionalData,
    };
  }
}