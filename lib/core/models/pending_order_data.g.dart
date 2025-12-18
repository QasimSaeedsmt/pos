// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_order_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingOrderDataAdapter extends TypeAdapter<PendingOrderData> {
  @override
  final int typeId = 4;

  @override
  PendingOrderData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingOrderData()
      ..id = fields[0] as int
      ..orderData = (fields[1] as Map).cast<String, dynamic>()
      ..customerData = (fields[2] as Map?)?.cast<String, dynamic>()
      ..paymentData = (fields[3] as Map).cast<String, dynamic>()
      ..discountSummary = (fields[4] as Map).cast<String, dynamic>()
      ..settingsUsed = (fields[5] as Map).cast<String, dynamic>()
      ..createdAt = fields[6] as String
      ..syncStatus = fields[7] as String
      ..syncAttempts = fields[8] as int
      ..version = fields[9] as String
      ..additionalData = (fields[10] as Map?)?.cast<String, dynamic>()
      ..lastSyncAttempt = fields[11] as String?;
  }

  @override
  void write(BinaryWriter writer, PendingOrderData obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderData)
      ..writeByte(2)
      ..write(obj.customerData)
      ..writeByte(3)
      ..write(obj.paymentData)
      ..writeByte(4)
      ..write(obj.discountSummary)
      ..writeByte(5)
      ..write(obj.settingsUsed)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.syncStatus)
      ..writeByte(8)
      ..write(obj.syncAttempts)
      ..writeByte(9)
      ..write(obj.version)
      ..writeByte(10)
      ..write(obj.additionalData)
      ..writeByte(11)
      ..write(obj.lastSyncAttempt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingOrderDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
