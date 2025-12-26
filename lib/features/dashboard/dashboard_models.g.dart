// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DashboardCacheAdapter extends TypeAdapter<DashboardCache> {
  @override
  final int typeId = 50;

  @override
  DashboardCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DashboardCache(
      tenantId: fields[0] as String,
      stats: fields[1] as DashboardStats,
      revenueData: (fields[2] as List).cast<RevenueDataPoint>(),
      productPerformance: (fields[3] as List).cast<ProductPerformance>(),
      lastUpdated: fields[4] as DateTime,
      cacheKey: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DashboardCache obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.tenantId)
      ..writeByte(1)
      ..write(obj.stats)
      ..writeByte(2)
      ..write(obj.revenueData)
      ..writeByte(3)
      ..write(obj.productPerformance)
      ..writeByte(4)
      ..write(obj.lastUpdated)
      ..writeByte(5)
      ..write(obj.cacheKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DashboardStatsAdapter extends TypeAdapter<DashboardStats> {
  @override
  final int typeId = 51;

  @override
  DashboardStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DashboardStats(
      totalRevenue: fields[0] as double,
      todayRevenue: fields[1] as double,
      totalSales: fields[2] as int,
      todaySales: fields[3] as int,
      totalProducts: fields[4] as int,
      lowStockProducts: fields[5] as int,
      totalCustomers: fields[6] as int,
      todayCustomers: fields[7] as int,
      averageOrderValue: fields[8] as double,
      conversionRate: fields[9] as double,
      revenueGrowth: fields[10] as double,
      salesGrowth: fields[11] as double,
      todayReturns: fields[12] as int,
      totalReturns: fields[13] as int,
      inventoryValue: fields[14] as double,
      pendingOrders: fields[15] as int,
      pendingReturns: fields[16] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DashboardStats obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.totalRevenue)
      ..writeByte(1)
      ..write(obj.todayRevenue)
      ..writeByte(2)
      ..write(obj.totalSales)
      ..writeByte(3)
      ..write(obj.todaySales)
      ..writeByte(4)
      ..write(obj.totalProducts)
      ..writeByte(5)
      ..write(obj.lowStockProducts)
      ..writeByte(6)
      ..write(obj.totalCustomers)
      ..writeByte(7)
      ..write(obj.todayCustomers)
      ..writeByte(8)
      ..write(obj.averageOrderValue)
      ..writeByte(9)
      ..write(obj.conversionRate)
      ..writeByte(10)
      ..write(obj.revenueGrowth)
      ..writeByte(11)
      ..write(obj.salesGrowth)
      ..writeByte(12)
      ..write(obj.todayReturns)
      ..writeByte(13)
      ..write(obj.totalReturns)
      ..writeByte(14)
      ..write(obj.inventoryValue)
      ..writeByte(15)
      ..write(obj.pendingOrders)
      ..writeByte(16)
      ..write(obj.pendingReturns);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RevenueDataPointAdapter extends TypeAdapter<RevenueDataPoint> {
  @override
  final int typeId = 52;

  @override
  RevenueDataPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RevenueDataPoint(
      date: fields[0] as DateTime,
      revenue: fields[1] as double,
      orders: fields[2] as int,
      customers: fields[3] as int,
      averageOrderValue: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RevenueDataPoint obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.revenue)
      ..writeByte(2)
      ..write(obj.orders)
      ..writeByte(3)
      ..write(obj.customers)
      ..writeByte(4)
      ..write(obj.averageOrderValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RevenueDataPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductPerformanceAdapter extends TypeAdapter<ProductPerformance> {
  @override
  final int typeId = 53;

  @override
  ProductPerformance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductPerformance(
      productId: fields[0] as String,
      productName: fields[1] as String,
      sku: fields[2] as String,
      quantitySold: fields[3] as int,
      revenue: fields[4] as double,
      profitMargin: fields[5] as double,
      stockQuantity: fields[6] as int,
      stockValue: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ProductPerformance obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.sku)
      ..writeByte(3)
      ..write(obj.quantitySold)
      ..writeByte(4)
      ..write(obj.revenue)
      ..writeByte(5)
      ..write(obj.profitMargin)
      ..writeByte(6)
      ..write(obj.stockQuantity)
      ..writeByte(7)
      ..write(obj.stockValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductPerformanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
