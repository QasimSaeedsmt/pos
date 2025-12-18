// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 14;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      sku: fields[2] as String,
      price: fields[3] as double,
      purchasePrice: fields[4] as double?,
      regularPrice: fields[5] as double?,
      salePrice: fields[6] as double?,
      imageUrl: fields[7] as String?,
      imageUrls: (fields[8] as List).cast<String>(),
      stockQuantity: fields[9] as int,
      inStock: fields[10] as bool,
      stockStatus: fields[11] as String,
      description: fields[12] as String?,
      shortDescription: fields[13] as String?,
      categories: (fields[14] as List).cast<Category>(),
      attributes: (fields[15] as List).cast<Attribute>(),
      metaData: (fields[16] as Map).cast<String, dynamic>(),
      dateCreated: fields[17] as DateTime?,
      dateModified: fields[18] as DateTime?,
      purchasable: fields[19] as bool,
      type: fields[20] as String?,
      status: fields[21] as String?,
      featured: fields[22] as bool,
      permalink: fields[23] as String?,
      averageRating: fields[24] as double?,
      ratingCount: fields[25] as int?,
      parentId: fields[26] as String?,
      variations: (fields[27] as List).cast<String>(),
      weight: fields[28] as String?,
      dimensions: fields[29] as String?,
      totalCostValue: fields[30] as double,
      totalUnitsPurchased: fields[31] as int,
      lastRestockDate: fields[32] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(33)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sku)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.purchasePrice)
      ..writeByte(5)
      ..write(obj.regularPrice)
      ..writeByte(6)
      ..write(obj.salePrice)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.imageUrls)
      ..writeByte(9)
      ..write(obj.stockQuantity)
      ..writeByte(10)
      ..write(obj.inStock)
      ..writeByte(11)
      ..write(obj.stockStatus)
      ..writeByte(12)
      ..write(obj.description)
      ..writeByte(13)
      ..write(obj.shortDescription)
      ..writeByte(14)
      ..write(obj.categories)
      ..writeByte(15)
      ..write(obj.attributes)
      ..writeByte(16)
      ..write(obj.metaData)
      ..writeByte(17)
      ..write(obj.dateCreated)
      ..writeByte(18)
      ..write(obj.dateModified)
      ..writeByte(19)
      ..write(obj.purchasable)
      ..writeByte(20)
      ..write(obj.type)
      ..writeByte(21)
      ..write(obj.status)
      ..writeByte(22)
      ..write(obj.featured)
      ..writeByte(23)
      ..write(obj.permalink)
      ..writeByte(24)
      ..write(obj.averageRating)
      ..writeByte(25)
      ..write(obj.ratingCount)
      ..writeByte(26)
      ..write(obj.parentId)
      ..writeByte(27)
      ..write(obj.variations)
      ..writeByte(28)
      ..write(obj.weight)
      ..writeByte(29)
      ..write(obj.dimensions)
      ..writeByte(30)
      ..write(obj.totalCostValue)
      ..writeByte(31)
      ..write(obj.totalUnitsPurchased)
      ..writeByte(32)
      ..write(obj.lastRestockDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
