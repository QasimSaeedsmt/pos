
import 'package:hive/hive.dart';

part 'pending_restock_data.g.dart';

@HiveType(typeId: 5)
class PendingRestockData extends HiveObject {
  @HiveField(0)
  late int id;

  @HiveField(1)
  late String productId;

  @HiveField(2)
  late int quantity;

  @HiveField(3)
  String? barcode;

  @HiveField(4)
  late String createdAt;

  @HiveField(5)
  late String syncStatus;

  @HiveField(6)
  late int syncAttempts;

  @HiveField(7)
  String? lastSyncAttempt;
}
