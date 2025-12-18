// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppOrderAdapter extends TypeAdapter<AppOrder> {
  @override
  final int typeId = 9;

  @override
  AppOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppOrder(
      id: fields[0] as String,
      number: fields[1] as String,
      dateCreated: fields[2] as DateTime,
      total: fields[3] as double,
      lineItems: (fields[4] as List).cast<dynamic>(),
      customerId: fields[5] as String?,
      customerName: fields[6] as String?,
      customerEmail: fields[7] as String?,
      customerPhone: fields[8] as String?,
      customerAddress: fields[9] as String?,
      customerData: (fields[10] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, AppOrder obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.number)
      ..writeByte(2)
      ..write(obj.dateCreated)
      ..writeByte(3)
      ..write(obj.total)
      ..writeByte(4)
      ..write(obj.lineItems)
      ..writeByte(5)
      ..write(obj.customerId)
      ..writeByte(6)
      ..write(obj.customerName)
      ..writeByte(7)
      ..write(obj.customerEmail)
      ..writeByte(8)
      ..write(obj.customerPhone)
      ..writeByte(9)
      ..write(obj.customerAddress)
      ..writeByte(10)
      ..write(obj.customerData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
