// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_return_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingReturnDataAdapter extends TypeAdapter<PendingReturnData> {
  @override
  final int typeId = 3;

  @override
  PendingReturnData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingReturnData()
      ..localId = fields[0] as int
      ..offlineId = fields[1] as String
      ..returnData = (fields[2] as Map).cast<String, dynamic>()
      ..syncStatus = fields[3] as String
      ..syncAttempts = fields[4] as int
      ..createdAt = fields[5] as String
      ..lastSyncAttempt = fields[6] as String?;
  }

  @override
  void write(BinaryWriter writer, PendingReturnData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.offlineId)
      ..writeByte(2)
      ..write(obj.returnData)
      ..writeByte(3)
      ..write(obj.syncStatus)
      ..writeByte(4)
      ..write(obj.syncAttempts)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.lastSyncAttempt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingReturnDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
