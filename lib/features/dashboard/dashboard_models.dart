// dashboard_models.dart
import 'package:hive/hive.dart';

part 'dashboard_models.g.dart';

// ========== DASHBOARD CACHE MODEL ==========
@HiveType(typeId: 50)
class DashboardCache {
  @HiveField(0)
  final String tenantId;

  @HiveField(1)
  final DashboardStats stats;

  @HiveField(2)
  final List<RevenueDataPoint> revenueData;

  @HiveField(3)
  final List<ProductPerformance> productPerformance;

  @HiveField(4)
  final DateTime lastUpdated;

  @HiveField(5)
  final String cacheKey;

  DashboardCache({
    required this.tenantId,
    required this.stats,
    required this.revenueData,
    required this.productPerformance,
    required this.lastUpdated,
    required this.cacheKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'tenantId': tenantId,
      'stats': stats.toJson(),
      'revenueData': revenueData.map((e) => e.toJson()).toList(),
      'productPerformance': productPerformance.map((e) => e.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'cacheKey': cacheKey,
    };
  }

  factory DashboardCache.fromJson(Map<String, dynamic> json) {
    return DashboardCache(
      tenantId: json['tenantId'],
      stats: DashboardStats.fromJson(json['stats']),
      revenueData: (json['revenueData'] as List)
          .map((e) => RevenueDataPoint.fromJson(e))
          .toList(),
      productPerformance: (json['productPerformance'] as List)
          .map((e) => ProductPerformance.fromJson(e))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      cacheKey: json['cacheKey'],
    );
  }
}

// ========== DASHBOARD STATS MODEL ==========
@HiveType(typeId: 51)
class DashboardStats {
  @HiveField(0)
  final double totalRevenue;

  @HiveField(1)
  final double todayRevenue;

  @HiveField(2)
  final int totalSales;

  @HiveField(3)
  final int todaySales;

  @HiveField(4)
  final int totalProducts;

  @HiveField(5)
  final int lowStockProducts;

  @HiveField(6)
  final int totalCustomers;

  @HiveField(7)
  final int todayCustomers;

  @HiveField(8)
  final double averageOrderValue;

  @HiveField(9)
  final double conversionRate;

  @HiveField(10)
  final double revenueGrowth;

  @HiveField(11)
  final double salesGrowth;

  @HiveField(12)
  final int todayReturns;

  @HiveField(13)
  final int totalReturns;

  @HiveField(14)
  final double inventoryValue;

  @HiveField(15)
  final int pendingOrders;

  @HiveField(16)
  final int pendingReturns;

  DashboardStats({
    required this.totalRevenue,
    required this.todayRevenue,
    required this.totalSales,
    required this.todaySales,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.totalCustomers,
    required this.todayCustomers,
    required this.averageOrderValue,
    required this.conversionRate,
    required this.revenueGrowth,
    required this.salesGrowth,
    required this.todayReturns,
    required this.totalReturns,
    required this.inventoryValue,
    required this.pendingOrders,
    required this.pendingReturns,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0,
      todayRevenue: 0,
      totalSales: 0,
      todaySales: 0,
      totalProducts: 0,
      lowStockProducts: 0,
      totalCustomers: 0,
      todayCustomers: 0,
      averageOrderValue: 0,
      conversionRate: 0,
      revenueGrowth: 0,
      salesGrowth: 0,
      todayReturns: 0,
      totalReturns: 0,
      inventoryValue: 0,
      pendingOrders: 0,
      pendingReturns: 0,
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      todayRevenue: (json['todayRevenue'] as num?)?.toDouble() ?? 0,
      totalSales: (json['totalSales'] as int?) ?? 0,
      todaySales: (json['todaySales'] as int?) ?? 0,
      totalProducts: (json['totalProducts'] as int?) ?? 0,
      lowStockProducts: (json['lowStockProducts'] as int?) ?? 0,
      totalCustomers: (json['totalCustomers'] as int?) ?? 0,
      todayCustomers: (json['todayCustomers'] as int?) ?? 0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0,
      revenueGrowth: (json['revenueGrowth'] as num?)?.toDouble() ?? 0,
      salesGrowth: (json['salesGrowth'] as num?)?.toDouble() ?? 0,
      todayReturns: (json['todayReturns'] as int?) ?? 0,
      totalReturns: (json['totalReturns'] as int?) ?? 0,
      inventoryValue: (json['inventoryValue'] as num?)?.toDouble() ?? 0,
      pendingOrders: (json['pendingOrders'] as int?) ?? 0,
      pendingReturns: (json['pendingReturns'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRevenue': totalRevenue,
      'todayRevenue': todayRevenue,
      'totalSales': totalSales,
      'todaySales': todaySales,
      'totalProducts': totalProducts,
      'lowStockProducts': lowStockProducts,
      'totalCustomers': totalCustomers,
      'todayCustomers': todayCustomers,
      'averageOrderValue': averageOrderValue,
      'conversionRate': conversionRate,
      'revenueGrowth': revenueGrowth,
      'salesGrowth': salesGrowth,
      'todayReturns': todayReturns,
      'totalReturns': totalReturns,
      'inventoryValue': inventoryValue,
      'pendingOrders': pendingOrders,
      'pendingReturns': pendingReturns,
    };
  }

  DashboardStats copyWith({
    double? totalRevenue,
    double? todayRevenue,
    int? totalSales,
    int? todaySales,
    int? totalProducts,
    int? lowStockProducts,
    int? totalCustomers,
    int? todayCustomers,
    double? averageOrderValue,
    double? conversionRate,
    double? revenueGrowth,
    double? salesGrowth,
    int? todayReturns,
    int? totalReturns,
    double? inventoryValue,
    int? pendingOrders,
    int? pendingReturns,
  }) {
    return DashboardStats(
      totalRevenue: totalRevenue ?? this.totalRevenue,
      todayRevenue: todayRevenue ?? this.todayRevenue,
      totalSales: totalSales ?? this.totalSales,
      todaySales: todaySales ?? this.todaySales,
      totalProducts: totalProducts ?? this.totalProducts,
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      totalCustomers: totalCustomers ?? this.totalCustomers,
      todayCustomers: todayCustomers ?? this.todayCustomers,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      conversionRate: conversionRate ?? this.conversionRate,
      revenueGrowth: revenueGrowth ?? this.revenueGrowth,
      salesGrowth: salesGrowth ?? this.salesGrowth,
      todayReturns: todayReturns ?? this.todayReturns,
      totalReturns: totalReturns ?? this.totalReturns,
      inventoryValue: inventoryValue ?? this.inventoryValue,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      pendingReturns: pendingReturns ?? this.pendingReturns,
    );
  }
}

// ========== REVENUE DATA POINT MODEL ==========
@HiveType(typeId: 52)
class RevenueDataPoint {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final double revenue;

  @HiveField(2)
  final int orders;

  @HiveField(3)
  final int customers;

  @HiveField(4)
  final double averageOrderValue;

  RevenueDataPoint({
    required this.date,
    required this.revenue,
    required this.orders,
    required this.customers,
    required this.averageOrderValue,
  });

  factory RevenueDataPoint.empty() {
    return RevenueDataPoint(
      date: DateTime.now(),
      revenue: 0,
      orders: 0,
      customers: 0,
      averageOrderValue: 0,
    );
  }

  factory RevenueDataPoint.fromJson(Map<String, dynamic> json) {
    return RevenueDataPoint(
      date: DateTime.parse(json['date']),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      orders: (json['orders'] as int?) ?? 0,
      customers: (json['customers'] as int?) ?? 0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'revenue': revenue,
      'orders': orders,
      'customers': customers,
      'averageOrderValue': averageOrderValue,
    };
  }
}

// ========== PRODUCT PERFORMANCE MODEL ==========
@HiveType(typeId: 53)
class ProductPerformance {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final String sku;

  @HiveField(3)
  final int quantitySold;

  @HiveField(4)
  final double revenue;

  @HiveField(5)
  final double profitMargin;

  @HiveField(6)
  final int stockQuantity;

  @HiveField(7)
  final double stockValue;

  ProductPerformance({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantitySold,
    required this.revenue,
    required this.profitMargin,
    required this.stockQuantity,
    required this.stockValue,
  });

  factory ProductPerformance.fromJson(Map<String, dynamic> json) {
    return ProductPerformance(
      productId: json['productId'],
      productName: json['productName'],
      sku: json['sku'],
      quantitySold: (json['quantitySold'] as int?) ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      profitMargin: (json['profitMargin'] as num?)?.toDouble() ?? 0,
      stockQuantity: (json['stockQuantity'] as int?) ?? 0,
      stockValue: (json['stockValue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'quantitySold': quantitySold,
      'revenue': revenue,
      'profitMargin': profitMargin,
      'stockQuantity': stockQuantity,
      'stockValue': stockValue,
    };
  }
}