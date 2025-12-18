import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/returnBase/return_base.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'return_request.g.dart';

@HiveType(typeId: 16)
class ReturnRequest {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String orderId;

  @HiveField(2)
  final String orderNumber;

  @HiveField(3)
  final List<ReturnItem> items;

  @HiveField(4)
  final String reason;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final String? notes;

  @HiveField(7)
  final DateTime dateCreated;

  @HiveField(8)
  final DateTime? dateUpdated;

  @HiveField(9)
  final double refundAmount;

  @HiveField(10)
  final String refundMethod;

  @HiveField(11)
  final String? customerId;

  @HiveField(12)
  final Map<String, dynamic>? customerInfo;

  @HiveField(13)
  final String? processedBy;

  @HiveField(14)
  final bool isOffline;

  @HiveField(15)
  final String? offlineId;

  @HiveField(16)
  final String syncStatus;

  ReturnRequest({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.items,
    required this.reason,
    required this.status,
    this.notes,
    required this.dateCreated,
    this.dateUpdated,
    required this.refundAmount,
    required this.refundMethod,
    this.customerId,
    this.customerInfo,
    this.processedBy,
    this.isOffline = false,
    this.offlineId,
    this.syncStatus = 'synced',
  });

  bool get isCompleted => status == 'completed' || status == 'refunded';
  bool get canRefund => status == 'approved' || status == 'completed';
  bool get needsSync => isOffline && syncStatus == 'pending';

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'reason': reason,
      'status': status,
      'notes': notes,
      'dateCreated': Timestamp.fromDate(dateCreated),
      'dateUpdated': dateUpdated != null
          ? Timestamp.fromDate(dateUpdated!)
          : FieldValue.serverTimestamp(),
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'customerId': customerId,
      'customerInfo': customerInfo,
      'processedBy': processedBy,
      'isOffline': isOffline,
      'offlineId': offlineId,
      'syncStatus': syncStatus,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'reason': reason,
      'status': status,
      'notes': notes,
      'dateCreated': dateCreated.toIso8601String(),
      'dateUpdated': dateUpdated?.toIso8601String(),
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'customerId': customerId,
      'customerInfo': customerInfo,
      'processedBy': processedBy,
      'isOffline': isOffline,
      'offlineId': offlineId,
      'syncStatus': syncStatus,
    };
  }

  factory ReturnRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return ReturnRequest(
      id: id,
      orderId: data['orderId'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => ReturnItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      dateCreated: (data['dateCreated'] as Timestamp).toDate(),
      dateUpdated: data['dateUpdated'] != null
          ? (data['dateUpdated'] as Timestamp).toDate()
          : null,
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
      refundMethod: data['refundMethod'] ?? 'original',
      customerId: data['customerId'],
      customerInfo: data['customerInfo'] != null
          ? Map<String, dynamic>.from(data['customerInfo'])
          : null,
      processedBy: data['processedBy'],
      isOffline: data['isOffline'] ?? false,
      offlineId: data['offlineId'],
      syncStatus: data['syncStatus'] ?? 'synced',
    );
  }

  factory ReturnRequest.fromLocalMap(Map<String, dynamic> data) {
    return ReturnRequest(
      id: data['id'] ?? '',
      orderId: data['orderId'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => ReturnItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      dateCreated: DateTime.parse(data['dateCreated']),
      dateUpdated: data['dateUpdated'] != null
          ? DateTime.parse(data['dateUpdated'])
          : null,
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
      refundMethod: data['refundMethod'] ?? 'original',
      customerId: data['customerId'],
      customerInfo: data['customerInfo'] != null
          ? Map<String, dynamic>.from(data['customerInfo'])
          : null,
      processedBy: data['processedBy'],
      isOffline: data['isOffline'] ?? false,
      offlineId: data['offlineId'],
      syncStatus: data['syncStatus'] ?? 'pending',
    );
  }

  ReturnRequest copyWith({
    String? status,
    String? notes,
    double? refundAmount,
    String? refundMethod,
    String? processedBy,
    String? syncStatus,
  }) {
    return ReturnRequest(
      id: id,
      orderId: orderId,
      orderNumber: orderNumber,
      items: items,
      reason: reason,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      dateCreated: dateCreated,
      dateUpdated: DateTime.now(),
      refundAmount: refundAmount ?? this.refundAmount,
      refundMethod: refundMethod ?? this.refundMethod,
      customerId: customerId,
      customerInfo: customerInfo,
      processedBy: processedBy ?? this.processedBy,
      isOffline: isOffline,
      offlineId: offlineId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  String toString() {
    return 'ReturnRequest{id: $id, orderNumber: $orderNumber, status: $status, refundAmount: $refundAmount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ReturnRequest &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}