// // GENERATED CODE - DO NOT MODIFY BY HAND
//
// part of 'offline_dashboard_data.dart';
//
// // **************************************************************************
// // TypeAdapterGenerator
// // **************************************************************************
//
// class OfflineDashboardDataAdapter extends TypeAdapter<OfflineDashboardData> {
//   @override
//   final int typeId = 6;
//
//   @override
//   OfflineDashboardData read(BinaryReader reader) {
//     final numOfFields = reader.readByte();
//     final fields = <int, dynamic>{
//       for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
//     };
//     return OfflineDashboardData()
//       ..tenantId = fields[0] as String
//       ..data = (fields[1] as Map).cast<String, dynamic>()
//       ..timestamp = fields[2] as int;
//   }
//
//   @override
//   void write(BinaryWriter writer, OfflineDashboardData obj) {
//     writer
//       ..writeByte(3)
//       ..writeByte(0)
//       ..write(obj.tenantId)
//       ..writeByte(1)
//       ..write(obj.data)
//       ..writeByte(2)
//       ..write(obj.timestamp);
//   }
//
//   @override
//   int get hashCode => typeId.hashCode;
//
//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is OfflineDashboardDataAdapter &&
//           runtimeType == other.runtimeType &&
//           typeId == other.typeId;
// }
