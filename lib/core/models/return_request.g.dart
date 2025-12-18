// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'return_request.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReturnRequestAdapter extends TypeAdapter<ReturnRequest> {
  @override
  final int typeId = 16;

  @override
  ReturnRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReturnRequest(
      id: fields[0] as String,
      orderId: fields[1] as String,
      orderNumber: fields[2] as String,
      items: (fields[3] as List).cast<ReturnItem>(),
      reason: fields[4] as String,
      status: fields[5] as String,
      notes: fields[6] as String?,
      dateCreated: fields[7] as DateTime,
      dateUpdated: fields[8] as DateTime?,
      refundAmount: fields[9] as double,
      refundMethod: fields[10] as String,
      customerId: fields[11] as String?,
      customerInfo: (fields[12] as Map?)?.cast<String, dynamic>(),
      processedBy: fields[13] as String?,
      isOffline: fields[14] as bool,
      offlineId: fields[15] as String?,
      syncStatus: fields[16] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ReturnRequest obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderId)
      ..writeByte(2)
      ..write(obj.orderNumber)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.reason)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.dateCreated)
      ..writeByte(8)
      ..write(obj.dateUpdated)
      ..writeByte(9)
      ..write(obj.refundAmount)
      ..writeByte(10)
      ..write(obj.refundMethod)
      ..writeByte(11)
      ..write(obj.customerId)
      ..writeByte(12)
      ..write(obj.customerInfo)
      ..writeByte(13)
      ..write(obj.processedBy)
      ..writeByte(14)
      ..write(obj.isOffline)
      ..writeByte(15)
      ..write(obj.offlineId)
      ..writeByte(16)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReturnRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
