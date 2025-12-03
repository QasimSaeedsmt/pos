import 'dart:convert';

/// Represents an analytics query with filters and date range
class AnalyticsQuery {
  final DateTime startDate;
  final DateTime endDate;
  final List<String>? productCategories;
  final List<String>? customerSegments;
  final String? reportType;
  final Map<String, dynamic> customFilters;

  AnalyticsQuery({
    required this.startDate,
    required this.endDate,
    this.productCategories,
    this.customerSegments,
    this.reportType = 'sales',
    this.customFilters = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'productCategories': productCategories,
      'customerSegments': customerSegments,
      'reportType': reportType,
      'customFilters': customFilters,
    };
  }

  factory AnalyticsQuery.fromMap(Map<String, dynamic> map) {
    return AnalyticsQuery(
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      productCategories: map['productCategories'] != null
          ? List<String>.from(map['productCategories'])
          : null,
      customerSegments: map['customerSegments'] != null
          ? List<String>.from(map['customerSegments'])
          : null,
      reportType: map['reportType'] ?? 'sales',
      customFilters: Map<String, dynamic>.from(map['customFilters'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());
  factory AnalyticsQuery.fromJson(String source) =>
      AnalyticsQuery.fromMap(json.decode(source));

  AnalyticsQuery copyWith({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? productCategories,
    List<String>? customerSegments,
    String? reportType,
    Map<String, dynamic>? customFilters,
  }) {
    return AnalyticsQuery(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      productCategories: productCategories ?? this.productCategories,
      customerSegments: customerSegments ?? this.customerSegments,
      reportType: reportType ?? this.reportType,
      customFilters: customFilters ?? this.customFilters,
    );
  }
}

/// Represents performance metrics for a given period
class PerformanceMetrics {
  final double totalRevenue;
  final double averageOrderValue;
  final int totalOrders;
  final int uniqueCustomers;
  final double conversionRate;
  final double revenueGrowth;
  final int itemsSold;
  final double profitMargin;

  const PerformanceMetrics({
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.totalOrders,
    required this.uniqueCustomers,
    required this.conversionRate,
    required this.revenueGrowth,
    required this.itemsSold,
    required this.profitMargin,
  });

  /// ---- DEFAULT EMPTY INSTANCE ----
  static final PerformanceMetrics empty = PerformanceMetrics(
    totalRevenue: 0,
    averageOrderValue: 0,
    totalOrders: 0,
    uniqueCustomers: 0,
    conversionRate: 0,
    revenueGrowth: 0,
    itemsSold: 0,
    profitMargin: 0,
  );

  /// ---- TO MAP ----
  Map<String, dynamic> toMap() {
    return {
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'totalOrders': totalOrders,
      'uniqueCustomers': uniqueCustomers,
      'conversionRate': conversionRate,
      'revenueGrowth': revenueGrowth,
      'itemsSold': itemsSold,
      'profitMargin': profitMargin,
    };
  }

  /// ---- FROM MAP ----
  factory PerformanceMetrics.fromMap(Map<String, dynamic> map) {
    return PerformanceMetrics(
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      averageOrderValue: (map['averageOrderValue'] ?? 0).toDouble(),
      totalOrders: (map['totalOrders'] ?? 0).toInt(),
      uniqueCustomers: (map['uniqueCustomers'] ?? 0).toInt(),
      conversionRate: (map['conversionRate'] ?? 0).toDouble(),
      revenueGrowth: (map['revenueGrowth'] ?? 0).toDouble(),
      itemsSold: (map['itemsSold'] ?? 0).toInt(),
      profitMargin: (map['profitMargin'] ?? 0).toDouble(),
    );
  }

  /// ---- COPY WITH ----
  PerformanceMetrics copyWith({
    double? totalRevenue,
    double? averageOrderValue,
    int? totalOrders,
    int? uniqueCustomers,
    double? conversionRate,
    double? revenueGrowth,
    int? itemsSold,
    double? profitMargin,
  }) {
    return PerformanceMetrics(
      totalRevenue: totalRevenue ?? this.totalRevenue,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      totalOrders: totalOrders ?? this.totalOrders,
      uniqueCustomers: uniqueCustomers ?? this.uniqueCustomers,
      conversionRate: conversionRate ?? this.conversionRate,
      revenueGrowth: revenueGrowth ?? this.revenueGrowth,
      itemsSold: itemsSold ?? this.itemsSold,
      profitMargin: profitMargin ?? this.profitMargin,
    );
  }

  /// ---- EQUALITY & HASHCODE ----
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PerformanceMetrics &&
        other.totalRevenue == totalRevenue &&
        other.averageOrderValue == averageOrderValue &&
        other.totalOrders == totalOrders &&
        other.uniqueCustomers == uniqueCustomers &&
        other.conversionRate == conversionRate &&
        other.revenueGrowth == revenueGrowth &&
        other.itemsSold == itemsSold &&
        other.profitMargin == profitMargin;
  }

  @override
  int get hashCode {
    return totalRevenue.hashCode ^
    averageOrderValue.hashCode ^
    totalOrders.hashCode ^
    uniqueCustomers.hashCode ^
    conversionRate.hashCode ^
    revenueGrowth.hashCode ^
    itemsSold.hashCode ^
    profitMargin.hashCode;
  }

  /// ---- TO STRING ----
  @override
  String toString() {
    return 'PerformanceMetrics('
        'totalRevenue: $totalRevenue, '
        'averageOrderValue: $averageOrderValue, '
        'totalOrders: $totalOrders, '
        'uniqueCustomers: $uniqueCustomers, '
        'conversionRate: $conversionRate, '
        'revenueGrowth: $revenueGrowth, '
        'itemsSold: $itemsSold, '
        'profitMargin: $profitMargin'
        ')';
  }
}

/// Time series data point for charts
class TimeSeriesData {
  final DateTime timestamp;
  final double value;
  final String label;
  final Map<String, dynamic>? metadata;

  TimeSeriesData({
    required this.timestamp,
    required this.value,
    required this.label,
    this.metadata,
  });
}