// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_restock_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingRestockDataAdapter extends TypeAdapter<PendingRestockData> {
  @override
  final int typeId = 5;

  @override
  PendingRestockData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingRestockData()
      ..id = fields[0] as int
      ..productId = fields[1] as String
      ..quantity = fields[2] as int
      ..barcode = fields[3] as String?
      ..createdAt = fields[4] as String
      ..syncStatus = fields[5] as String
      ..syncAttempts = fields[6] as int
      ..lastSyncAttempt = fields[7] as String?;
  }

  @override
  void write(BinaryWriter writer, PendingRestockData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.barcode)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.syncStatus)
      ..writeByte(6)
      ..write(obj.syncAttempts)
      ..writeByte(7)
      ..write(obj.lastSyncAttempt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingRestockDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
