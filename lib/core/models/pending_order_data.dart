import 'package:hive/hive.dart';

part 'pending_order_data.g.dart';

@HiveType(typeId: 4)
class PendingOrderData extends HiveObject {
  @HiveField(0)
  late int id;

  @HiveField(1)
  late Map<String, dynamic> orderData;

  @HiveField(2)
  Map<String, dynamic>? customerData;

  @HiveField(3)
  late Map<String, dynamic> paymentData;

  @HiveField(4)
  late Map<String, dynamic> discountSummary;

  @HiveField(5)
  late Map<String, dynamic> settingsUsed;

  @HiveField(6)
  late String createdAt;

  @HiveField(7)
  late String syncStatus;

  @HiveField(8)
  late int syncAttempts;

  @HiveField(9)
  late String version;

  @HiveField(10)
  Map<String, dynamic>? additionalData;

  @HiveField(11)
  String? lastSyncAttempt;
}