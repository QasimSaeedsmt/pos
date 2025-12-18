// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingOrderAdapter extends TypeAdapter<PendingOrder> {
  @override
  final int typeId = 14;

  @override
  PendingOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingOrder(
      id: fields[0] as int,
      orderData: (fields[1] as Map).cast<String, dynamic>(),
      customerData: (fields[2] as Map?)?.cast<String, dynamic>(),
      paymentData: (fields[3] as Map).cast<String, dynamic>(),
      discountSummary: (fields[4] as Map).cast<String, dynamic>(),
      settingsUsed: (fields[5] as Map).cast<String, dynamic>(),
      createdAt: fields[6] as DateTime,
      syncStatus: fields[7] as String,
      syncAttempts: fields[8] as int,
      version: fields[9] as String,
      additionalData: (fields[10] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, PendingOrder obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.additionalData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
