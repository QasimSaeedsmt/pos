// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 13;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      id: fields[0] as String,
      firstName: fields[1] as String,
      lastName: fields[2] as String,
      email: fields[3] as String,
      phone: fields[4] as String,
      company: fields[5] as String?,
      address1: fields[6] as String?,
      address2: fields[7] as String?,
      city: fields[8] as String?,
      state: fields[9] as String?,
      postcode: fields[10] as String?,
      country: fields[11] as String?,
      dateCreated: fields[12] as DateTime?,
      dateModified: fields[13] as DateTime?,
      orderCount: fields[14] as int,
      totalSpent: fields[15] as double,
      notes: fields[16] as String?,
      metaData: (fields[17] as Map).cast<String, dynamic>(),
      creditLimit: fields[18] as double,
      currentBalance: fields[19] as double,
      totalCreditGiven: fields[20] as double,
      totalCreditPaid: fields[21] as double,
      lastCreditDate: fields[22] as DateTime?,
      lastPaymentDate: fields[23] as DateTime?,
      creditTerms: (fields[24] as Map).cast<String, dynamic>(),
      overdueAmount: fields[25] as double,
      overdueCount: fields[26] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.firstName)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.company)
      ..writeByte(6)
      ..write(obj.address1)
      ..writeByte(7)
      ..write(obj.address2)
      ..writeByte(8)
      ..write(obj.city)
      ..writeByte(9)
      ..write(obj.state)
      ..writeByte(10)
      ..write(obj.postcode)
      ..writeByte(11)
      ..write(obj.country)
      ..writeByte(12)
      ..write(obj.dateCreated)
      ..writeByte(13)
      ..write(obj.dateModified)
      ..writeByte(14)
      ..write(obj.orderCount)
      ..writeByte(15)
      ..write(obj.totalSpent)
      ..writeByte(16)
      ..write(obj.notes)
      ..writeByte(17)
      ..write(obj.metaData)
      ..writeByte(18)
      ..write(obj.creditLimit)
      ..writeByte(19)
      ..write(obj.currentBalance)
      ..writeByte(20)
      ..write(obj.totalCreditGiven)
      ..writeByte(21)
      ..write(obj.totalCreditPaid)
      ..writeByte(22)
      ..write(obj.lastCreditDate)
      ..writeByte(23)
      ..write(obj.lastPaymentDate)
      ..writeByte(24)
      ..write(obj.creditTerms)
      ..writeByte(25)
      ..write(obj.overdueAmount)
      ..writeByte(26)
      ..write(obj.overdueCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
