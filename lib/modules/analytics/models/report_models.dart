import 'dart:convert';

import 'analytics_models.dart';

/// Base class for all report types
abstract class BaseReport {
  final String id;
  final String name;
  final DateTime generatedAt;
  final AnalyticsQuery query;
  final Map<String, dynamic> data;

  BaseReport({
    required this.id,
    required this.name,
    required this.generatedAt,
    required this.query,
    required this.data,
  });

  Map<String, dynamic> toMap();
  String toJson() => json.encode(toMap());
}

/// Sales report with detailed breakdown
class SalesReport implements BaseReport {
  @override
  final String id;
  @override
  final String name;
  @override
  final DateTime generatedAt;
  @override
  final AnalyticsQuery query;
  @override
  final Map<String, dynamic> data;

  // Sales-specific fields
  final double totalSales;
  final double averageSaleValue;
  final int numberOfTransactions;
  final List<SalesByCategory> salesByCategory;
  final List<SalesByHour> salesByHour;
  final List<SalesByDay> salesByDay;
  final List<TopSellingProduct> topProducts;
  final List<SalesTrend> salesTrends;

  SalesReport({
    required this.id,
    required this.name,
    required this.generatedAt,
    required this.query,
    required this.data,
    required this.totalSales,
    required this.averageSaleValue,
    required this.numberOfTransactions,
    required this.salesByCategory,
    required this.salesByHour,
    required this.salesByDay,
    required this.topProducts,
    required this.salesTrends,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'generatedAt': generatedAt.toIso8601String(),
      'query': query.toMap(),
      'data': data,
      'totalSales': totalSales,
      'averageSaleValue': averageSaleValue,
      'numberOfTransactions': numberOfTransactions,
      'salesByCategory': salesByCategory.map((x) => x.toMap()).toList(),
      'salesByHour': salesByHour.map((x) => x.toMap()).toList(),
      'salesByDay': salesByDay.map((x) => x.toMap()).toList(),
      'topProducts': topProducts.map((x) => x.toMap()).toList(),
      'salesTrends': salesTrends.map((x) => x.toMap()).toList(),
    };
  }

  factory SalesReport.fromMap(Map<String, dynamic> map) {
    return SalesReport(
      id: map['id'],
      name: map['name'],
      generatedAt: DateTime.parse(map['generatedAt']),
      query: AnalyticsQuery.fromMap(map['query']),
      data: Map<String, dynamic>.from(map['data']),
      totalSales: map['totalSales']?.toDouble() ?? 0.0,
      averageSaleValue: map['averageSaleValue']?.toDouble() ?? 0.0,
      numberOfTransactions: map['numberOfTransactions']?.toInt() ?? 0,
      salesByCategory: List<SalesByCategory>.from(
        map['salesByCategory']?.map((x) => SalesByCategory.fromMap(x)) ?? [],
      ),
      salesByHour: List<SalesByHour>.from(
        map['salesByHour']?.map((x) => SalesByHour.fromMap(x)) ?? [],
      ),
      salesByDay: List<SalesByDay>.from(
        map['salesByDay']?.map((x) => SalesByDay.fromMap(x)) ?? [],
      ),
      topProducts: List<TopSellingProduct>.from(
        map['topProducts']?.map((x) => TopSellingProduct.fromMap(x)) ?? [],
      ),
      salesTrends: List<SalesTrend>.from(
        map['salesTrends']?.map((x) => SalesTrend.fromMap(x)) ?? [],
      ),
    );
  }

  static SalesReport get empty => SalesReport(
    id: '',
    name: 'Empty Report',
    generatedAt: DateTime.now(),
    query: AnalyticsQuery(
      startDate: DateTime.now(),
      endDate: DateTime.now(),
    ),
    data: {},
    totalSales: 0,
    averageSaleValue: 0,
    numberOfTransactions: 0,
    salesByCategory: [],
    salesByHour: [],
    salesByDay: [],
    topProducts: [],
    salesTrends: [],
  );

  @override
  String toJson() {
    // TODO: implement toJson
    throw UnimplementedError();
  }
}

/// Sales by category breakdown
class SalesByCategory {
  final String categoryId;
  final String categoryName;
  final double totalSales;
  final int itemsSold;
  final double percentageOfTotal;

  SalesByCategory({
    required this.categoryId,
    required this.categoryName,
    required this.totalSales,
    required this.itemsSold,
    required this.percentageOfTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'totalSales': totalSales,
      'itemsSold': itemsSold,
      'percentageOfTotal': percentageOfTotal,
    };
  }

  factory SalesByCategory.fromMap(Map<String, dynamic> map) {
    return SalesByCategory(
      categoryId: map['categoryId'],
      categoryName: map['categoryName'],
      totalSales: map['totalSales']?.toDouble() ?? 0.0,
      itemsSold: map['itemsSold']?.toInt() ?? 0,
      percentageOfTotal: map['percentageOfTotal']?.toDouble() ?? 0.0,
    );
  }
}

/// Sales by hour of day
class SalesByHour {
  final int hour;
  final double totalSales;
  final int numberOfTransactions;

  SalesByHour({
    required this.hour,
    required this.totalSales,
    required this.numberOfTransactions,
  });

  Map<String, dynamic> toMap() {
    return {
      'hour': hour,
      'totalSales': totalSales,
      'numberOfTransactions': numberOfTransactions,
    };
  }

  factory SalesByHour.fromMap(Map<String, dynamic> map) {
    return SalesByHour(
      hour: map['hour']?.toInt() ?? 0,
      totalSales: map['totalSales']?.toDouble() ?? 0.0,
      numberOfTransactions: map['numberOfTransactions']?.toInt() ?? 0,
    );
  }
}

/// Sales by day of week
class SalesByDay {
  final String dayName;
  final int dayIndex;
  final double totalSales;
  final int numberOfTransactions;

  SalesByDay({
    required this.dayName,
    required this.dayIndex,
    required this.totalSales,
    required this.numberOfTransactions,
  });

  Map<String, dynamic> toMap() {
    return {
      'dayName': dayName,
      'dayIndex': dayIndex,
      'totalSales': totalSales,
      'numberOfTransactions': numberOfTransactions,
    };
  }

  factory SalesByDay.fromMap(Map<String, dynamic> map) {
    return SalesByDay(
      dayName: map['dayName'],
      dayIndex: map['dayIndex']?.toInt() ?? 0,
      totalSales: map['totalSales']?.toDouble() ?? 0.0,
      numberOfTransactions: map['numberOfTransactions']?.toInt() ?? 0,
    );
  }
}

/// Top selling product
class TopSellingProduct {
  final String productId;
  final String productName;
  final String productSku;
  final int quantitySold;
  final double totalRevenue;
  final double profitMargin;

  TopSellingProduct({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantitySold,
    required this.totalRevenue,
    required this.profitMargin,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productSku': productSku,
      'quantitySold': quantitySold,
      'totalRevenue': totalRevenue,
      'profitMargin': profitMargin,
    };
  }

  factory TopSellingProduct.fromMap(Map<String, dynamic> map) {
    return TopSellingProduct(
      productId: map['productId'],
      productName: map['productName'],
      productSku: map['productSku'],
      quantitySold: map['quantitySold']?.toInt() ?? 0,
      totalRevenue: map['totalRevenue']?.toDouble() ?? 0.0,
      profitMargin: map['profitMargin']?.toDouble() ?? 0.0,
    );
  }
}

/// Sales trend over time
class SalesTrend {
  final DateTime date;
  final double salesAmount;
  final int transactionCount;

  SalesTrend({
    required this.date,
    required this.salesAmount,
    required this.transactionCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'salesAmount': salesAmount,
      'transactionCount': transactionCount,
    };
  }

  factory SalesTrend.fromMap(Map<String, dynamic> map) {
    return SalesTrend(
      date: DateTime.parse(map['date']),
      salesAmount: map['salesAmount']?.toDouble() ?? 0.0,
      transactionCount: map['transactionCount']?.toInt() ?? 0,
    );
  }
}

/// Inventory report
class InventoryReport implements BaseReport {
  @override
  final String id;
  @override
  final String name;
  @override
  final DateTime generatedAt;
  @override
  final AnalyticsQuery query;
  @override
  final Map<String, dynamic> data;

  // Inventory-specific fields
  final double totalInventoryValue;
  final int lowStockItems;
  final int outOfStockItems;
  final List<InventoryItem> slowMovingItems;
  final List<InventoryItem> fastMovingItems;
  final double inventoryTurnoverRate;

  InventoryReport({
    required this.id,
    required this.name,
    required this.generatedAt,
    required this.query,
    required this.data,
    required this.totalInventoryValue,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.slowMovingItems,
    required this.fastMovingItems,
    required this.inventoryTurnoverRate,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'generatedAt': generatedAt.toIso8601String(),
      'query': query.toMap(),
      'data': data,
      'totalInventoryValue': totalInventoryValue,
      'lowStockItems': lowStockItems,
      'outOfStockItems': outOfStockItems,
      'slowMovingItems': slowMovingItems.map((x) => x.toMap()).toList(),
      'fastMovingItems': fastMovingItems.map((x) => x.toMap()).toList(),
      'inventoryTurnoverRate': inventoryTurnoverRate,
    };
  }

  factory InventoryReport.fromMap(Map<String, dynamic> map) {
    return InventoryReport(
      id: map['id'],
      name: map['name'],
      generatedAt: DateTime.parse(map['generatedAt']),
      query: AnalyticsQuery.fromMap(map['query']),
      data: Map<String, dynamic>.from(map['data']),
      totalInventoryValue: map['totalInventoryValue']?.toDouble() ?? 0.0,
      lowStockItems: map['lowStockItems']?.toInt() ?? 0,
      outOfStockItems: map['outOfStockItems']?.toInt() ?? 0,
      slowMovingItems: List<InventoryItem>.from(
        map['slowMovingItems']?.map((x) => InventoryItem.fromMap(x)) ?? [],
      ),
      fastMovingItems: List<InventoryItem>.from(
        map['fastMovingItems']?.map((x) => InventoryItem.fromMap(x)) ?? [],
      ),
      inventoryTurnoverRate: map['inventoryTurnoverRate']?.toDouble() ?? 0.0,
    );
  }

  static InventoryReport get empty => InventoryReport(
    id: '',
    name: 'Empty Inventory Report',
    generatedAt: DateTime.now(),
    query: AnalyticsQuery(
      startDate: DateTime.now(),
      endDate: DateTime.now(),
    ),
    data: {},
    totalInventoryValue: 0,
    lowStockItems: 0,
    outOfStockItems: 0,
    slowMovingItems: [],
    fastMovingItems: [],
    inventoryTurnoverRate: 0,
  );

  @override
  String toJson() {
    // TODO: implement toJson
    throw UnimplementedError();
  }
}

/// Inventory item details
class InventoryItem {
  final String productId;
  final String productName;
  final String sku;
  final int currentStock;
  final int minStockLevel;
  final int maxStockLevel;
  final double unitCost;
  final double retailPrice;
  final int daysInStock;
  final double stockValue;

  InventoryItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.currentStock,
    required this.minStockLevel,
    required this.maxStockLevel,
    required this.unitCost,
    required this.retailPrice,
    required this.daysInStock,
    required this.stockValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'currentStock': currentStock,
      'minStockLevel': minStockLevel,
      'maxStockLevel': maxStockLevel,
      'unitCost': unitCost,
      'retailPrice': retailPrice,
      'daysInStock': daysInStock,
      'stockValue': stockValue,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      productId: map['productId'],
      productName: map['productName'],
      sku: map['sku'],
      currentStock: map['currentStock']?.toInt() ?? 0,
      minStockLevel: map['minStockLevel']?.toInt() ?? 0,
      maxStockLevel: map['maxStockLevel']?.toInt() ?? 0,
      unitCost: map['unitCost']?.toDouble() ?? 0.0,
      retailPrice: map['retailPrice']?.toDouble() ?? 0.0,
      daysInStock: map['daysInStock']?.toInt() ?? 0,
      stockValue: map['stockValue']?.toDouble() ?? 0.0,
    );
  }

  bool get isLowStock => currentStock <= minStockLevel;
  bool get isOutOfStock => currentStock == 0;
  double get profitMargin => retailPrice - unitCost;
}