// Hive data models for complex types
import 'package:hive/hive.dart';

part 'pending_return_data.g.dart';
@HiveType(typeId: 3)
class PendingReturnData extends HiveObject {
  @HiveField(0)
  late int localId;

  @HiveField(1)
  late String offlineId;

  @HiveField(2)
  late Map<String, dynamic> returnData;

  @HiveField(3)
  late String syncStatus;

  @HiveField(4)
  late int syncAttempts;

  @HiveField(5)
  late String createdAt;

  @HiveField(6)
  String? lastSyncAttempt;
}

