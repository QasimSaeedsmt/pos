// // dashboard_data_service.dart
// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:csv/csv.dart';
// import 'package:syncfusion_flutter_pdf/pdf.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:intl/intl.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
//
// import '../../constants.dart';
// import '../../core/models/category_model.dart';
// import '../../core/models/customer_model.dart';
// import '../../core/models/product_model.dart';
// import '../clientDashboard/client_dashboard.dart';
// import '../connectivityBase/local_db_base.dart';
// import '../main_navigation/main_navigation_base.dart';
//
// class EnhancedDashboardData {
//   final DashboardStats stats;
//   final List<RevenueDataPoint> revenueData;
//   final List<CategoryDistribution> categoryDistribution;
//   final List<HourlySalesData> hourlySales;
//   final List<PaymentMethodData> paymentMethods;
//   final CustomerAnalytics customerAnalytics;
//   final DateTime lastUpdated;
//   final String tenantId;
//   final String syncStatus;
//   final int dataVersion;
//
//   EnhancedDashboardData({
//     required this.stats,
//     required this.revenueData,
//     required this.categoryDistribution,
//     required this.hourlySales,
//     required this.paymentMethods,
//     required this.customerAnalytics,
//     required this.lastUpdated,
//     required this.tenantId,
//     this.syncStatus = 'synced',
//     this.dataVersion = 1,
//   });
//
//   Map<String, dynamic> toJson() {
//     return {
//       'stats': {
//         'totalRevenue': stats.totalRevenue,
//         'todayRevenue': stats.todayRevenue,
//         'totalSales': stats.totalSales,
//         'todaySales': stats.todaySales,
//         'totalProducts': stats.totalProducts,
//         'lowStockProducts': stats.lowStockProducts,
//         'totalCustomers': stats.totalCustomers,
//         'todayCustomers': stats.todayCustomers,
//         'averageOrderValue': stats.averageOrderValue,
//         'conversionRate': stats.conversionRate,
//         'revenueGrowth': stats.revenueGrowth,
//         'salesGrowth': stats.salesGrowth,
//         'todayReturns': stats.todayReturns,
//         'totalReturns': stats.totalReturns,
//       },
//       'revenueData': revenueData.map((point) => {
//         'date': point.date.toIso8601String(),
//         'revenue': point.revenue,
//         'orders': point.orders,
//       }).toList(),
//       'categoryDistribution': categoryDistribution.map((cat) => {
//         'categoryName': cat.categoryName,
//         'revenue': cat.revenue,
//         'orders': cat.orders,
//         'percentage': cat.percentage,
//       }).toList(),
//       'hourlySales': hourlySales.map((hour) => {
//         'hour': hour.hour,
//         'revenue': hour.revenue,
//         'orders': hour.orders,
//       }).toList(),
//       'paymentMethods': paymentMethods.map((method) => {
//         'method': method.method,
//         'count': method.count,
//         'amount': method.amount,
//         'percentage': method.percentage,
//       }).toList(),
//       'customerAnalytics': {
//         'newCustomers': customerAnalytics.newCustomers,
//         'returningCustomers': customerAnalytics.returningCustomers,
//         'customerGrowth': customerAnalytics.customerGrowth,
//         'retentionRate': customerAnalytics.retentionRate,
//         'averageCustomerValue': customerAnalytics.averageCustomerValue,
//       },
//       'lastUpdated': lastUpdated.toIso8601String(),
//       'tenantId': tenantId,
//       'syncStatus': syncStatus,
//       'dataVersion': dataVersion,
//     };
//   }
//
//   factory EnhancedDashboardData.fromJson(Map<String, dynamic> json) {
//     return EnhancedDashboardData(
//       stats: DashboardStats(
//         totalRevenue: json['stats']['totalRevenue'] ?? 0.0,
//         todayRevenue: json['stats']['todayRevenue'] ?? 0.0,
//         totalSales: json['stats']['totalSales'] ?? 0,
//         todaySales: json['stats']['todaySales'] ?? 0,
//         totalProducts: json['stats']['totalProducts'] ?? 0,
//         lowStockProducts: json['stats']['lowStockProducts'] ?? 0,
//         totalCustomers: json['stats']['totalCustomers'] ?? 0,
//         todayCustomers: json['stats']['todayCustomers'] ?? 0,
//         averageOrderValue: json['stats']['averageOrderValue'] ?? 0.0,
//         conversionRate: json['stats']['conversionRate'] ?? 0.0,
//         revenueGrowth: json['stats']['revenueGrowth'] ?? 0.0,
//         salesGrowth: json['stats']['salesGrowth'] ?? 0.0,
//         todayReturns: json['stats']['todayReturns'] ?? 0,
//         totalReturns: json['stats']['totalReturns'] ?? 0,
//       ),
//       revenueData: (json['revenueData'] as List<dynamic>).map((pointJson) {
//         return RevenueDataPoint(
//           date: DateTime.parse(pointJson['date']),
//           revenue: pointJson['revenue'] ?? 0.0,
//           orders: pointJson['orders'] ?? 0,
//         );
//       }).toList(),
//       categoryDistribution: (json['categoryDistribution'] as List<dynamic>).map((catJson) {
//         return CategoryDistribution(
//           categoryName: catJson['categoryName'] ?? '',
//           revenue: catJson['revenue'] ?? 0.0,
//           orders: catJson['orders'] ?? 0,
//           percentage: catJson['percentage'] ?? 0.0,
//         );
//       }).toList(),
//       hourlySales: (json['hourlySales'] as List<dynamic>).map((hourJson) {
//         return HourlySalesData(
//           hour: hourJson['hour'] ?? 0,
//           revenue: hourJson['revenue'] ?? 0.0,
//           orders: hourJson['orders'] ?? 0,
//         );
//       }).toList(),
//       paymentMethods: (json['paymentMethods'] as List<dynamic>).map((methodJson) {
//         return PaymentMethodData(
//           method: methodJson['method'] ?? '',
//           count: methodJson['count'] ?? 0,
//           amount: methodJson['amount'] ?? 0.0,
//           percentage: methodJson['percentage'] ?? 0.0,
//         );
//       }).toList(),
//       customerAnalytics: CustomerAnalytics(
//         newCustomers: json['customerAnalytics']['newCustomers'] ?? 0,
//         returningCustomers: json['customerAnalytics']['returningCustomers'] ?? 0,
//         customerGrowth: json['customerAnalytics']['customerGrowth'] ?? 0.0,
//         retentionRate: json['customerAnalytics']['retentionRate'] ?? 0.0,
//         averageCustomerValue: json['customerAnalytics']['averageCustomerValue'] ?? 0.0,
//       ),
//       lastUpdated: DateTime.parse(json['lastUpdated']),
//       tenantId: json['tenantId'] ?? '',
//       syncStatus: json['syncStatus'] ?? 'synced',
//       dataVersion: json['dataVersion'] ?? 1,
//     );
//   }
//
//   EnhancedDashboardData mergeWith(EnhancedDashboardData other) {
//     // Conflict resolution: Use most recent data with version check
//     if (other.dataVersion > dataVersion) {
//       return other;
//     } else if (other.lastUpdated.isAfter(lastUpdated)) {
//       return EnhancedDashboardData(
//         stats: DashboardStats(
//           totalRevenue: other.stats.totalRevenue,
//           todayRevenue: other.stats.todayRevenue,
//           totalSales: other.stats.totalSales,
//           todaySales: other.stats.todaySales,
//           totalProducts: other.stats.totalProducts,
//           lowStockProducts: other.stats.lowStockProducts,
//           totalCustomers: other.stats.totalCustomers,
//           todayCustomers: other.stats.todayCustomers,
//           averageOrderValue: (stats.averageOrderValue + other.stats.averageOrderValue) / 2,
//           conversionRate: (stats.conversionRate + other.stats.conversionRate) / 2,
//           revenueGrowth: other.stats.revenueGrowth,
//           salesGrowth: other.stats.salesGrowth,
//           todayReturns: other.stats.todayReturns,
//           totalReturns: other.stats.totalReturns,
//         ),
//         revenueData: _mergeRevenueData(other.revenueData),
//         categoryDistribution: _mergeCategoryDistribution(other.categoryDistribution),
//         hourlySales: _mergeHourlySales(other.hourlySales),
//         paymentMethods: _mergePaymentMethods(other.paymentMethods),
//         customerAnalytics: CustomerAnalytics(
//           newCustomers: other.customerAnalytics.newCustomers,
//           returningCustomers: other.customerAnalytics.returningCustomers,
//           customerGrowth: other.customerAnalytics.customerGrowth,
//           retentionRate: (customerAnalytics.retentionRate + other.customerAnalytics.retentionRate) / 2,
//           averageCustomerValue: (customerAnalytics.averageCustomerValue + other.customerAnalytics.averageCustomerValue) / 2,
//         ),
//         lastUpdated: DateTime.now(),
//         tenantId: tenantId,
//         syncStatus: 'merged',
//         dataVersion: dataVersion + 1,
//       );
//     }
//     return this;
//   }
//
//   List<RevenueDataPoint> _mergeRevenueData(List<RevenueDataPoint> other) {
//     final Map<String, RevenueDataPoint> merged = {};
//
//     for (final point in revenueData) {
//       final key = DateFormat('yyyy-MM-dd').format(point.date);
//       merged[key] = point;
//     }
//
//     for (final point in other) {
//       final key = DateFormat('yyyy-MM-dd').format(point.date);
//       if (merged.containsKey(key)) {
//         final existing = merged[key]!;
//         merged[key] = RevenueDataPoint(
//           date: point.date,
//           revenue: (existing.revenue + point.revenue) / 2,
//           orders: (existing.orders + point.orders) ~/ 2,
//         );
//       } else {
//         merged[key] = point;
//       }
//     }
//
//     return merged.values.toList();
//   }
//
//   List<CategoryDistribution> _mergeCategoryDistribution(List<CategoryDistribution> other) {
//     final Map<String, CategoryDistribution> merged = {};
//
//     for (final cat in categoryDistribution) {
//       merged[cat.categoryName] = cat;
//     }
//
//     for (final cat in other) {
//       if (merged.containsKey(cat.categoryName)) {
//         final existing = merged[cat.categoryName]!;
//         merged[cat.categoryName] = CategoryDistribution(
//           categoryName: cat.categoryName,
//           revenue: (existing.revenue + cat.revenue) / 2,
//           orders: (existing.orders + cat.orders) ~/ 2,
//           percentage: (existing.percentage + cat.percentage) / 2,
//         );
//       } else {
//         merged[cat.categoryName] = cat;
//       }
//     }
//
//     return merged.values.toList();
//   }
//
//   List<HourlySalesData> _mergeHourlySales(List<HourlySalesData> other) {
//     final Map<int, HourlySalesData> merged = {};
//
//     for (final hour in hourlySales) {
//       merged[hour.hour] = hour;
//     }
//
//     for (final hour in other) {
//       if (merged.containsKey(hour.hour)) {
//         final existing = merged[hour.hour]!;
//         merged[hour.hour] = HourlySalesData(
//           hour: hour.hour,
//           revenue: (existing.revenue + hour.revenue) / 2,
//           orders: (existing.orders + hour.orders) ~/ 2,
//         );
//       } else {
//         merged[hour.hour] = hour;
//       }
//     }
//
//     return merged.values.toList();
//   }
//
//   List<PaymentMethodData> _mergePaymentMethods(List<PaymentMethodData> other) {
//     final Map<String, PaymentMethodData> merged = {};
//
//     for (final method in paymentMethods) {
//       merged[method.method] = method;
//     }
//
//     for (final method in other) {
//       if (merged.containsKey(method.method)) {
//         final existing = merged[method.method]!;
//         merged[method.method] = PaymentMethodData(
//           method: method.method,
//           count: (existing.count + method.count) ~/ 2,
//           amount: (existing.amount + method.amount) / 2,
//           percentage: (existing.percentage + method.percentage) / 2,
//         );
//       } else {
//         merged[method.method] = method;
//       }
//     }
//
//     return merged.values.toList();
//   }
// }
//
// class CategoryDistribution {
//   final String categoryName;
//   final double revenue;
//   final int orders;
//   final double percentage;
//
//   CategoryDistribution({
//     required this.categoryName,
//     required this.revenue,
//     required this.orders,
//     required this.percentage,
//   });
// }
//
// class HourlySalesData {
//   final int hour;
//   final double revenue;
//   final int orders;
//
//   HourlySalesData({
//     required this.hour,
//     required this.revenue,
//     required this.orders,
//   });
// }
//
// class PaymentMethodData {
//   final String method;
//   final int count;
//   final double amount;
//   final double percentage;
//
//   PaymentMethodData({
//     required this.method,
//     required this.count,
//     required this.amount,
//     required this.percentage,
//   });
// }
//
// class CustomerAnalytics {
//   final int newCustomers;
//   final int returningCustomers;
//   final double customerGrowth;
//   final double retentionRate;
//   final double averageCustomerValue;
//
//   CustomerAnalytics({
//     required this.newCustomers,
//     required this.returningCustomers,
//     required this.customerGrowth,
//     required this.retentionRate,
//     required this.averageCustomerValue,
//   });
// }
//
// class DashboardExportService {
//   static Future<String> exportToPDF(EnhancedDashboardData data) async {
//     final PdfDocument document = PdfDocument();
//     final PdfPage page = document.pages.add();
//     final PdfGraphics graphics = page.graphics;
//     final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 20);
//     final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 14);
//     final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
//     final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm');
//
//     // Header
//     graphics.drawString(
//       'Dashboard Report',
//       headerFont,
//       brush: PdfBrushes.black,
//       bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 50),
//       format: PdfStringFormat(alignment: PdfTextAlignment.center),
//     );
//
//     graphics.drawString(
//       'Generated: ${dateFormat.format(data.lastUpdated)}',
//       bodyFont,
//       brush: PdfBrushes.gray,
//       bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
//       format: PdfStringFormat(alignment: PdfTextAlignment.center),
//     );
//
//     double y = 60;
//
//     // Stats Section
//     graphics.drawString(
//       'Business Performance',
//       titleFont,
//       brush: PdfBrushes.darkBlue,
//       bounds: Rect.fromLTWH(50, y, page.getClientSize().width - 100, 30),
//     );
//
//     y += 40;
//
//     final List<List<String>> statsTable = [
//       ['Metric', 'Value', 'Today'],
//       ['Total Revenue', '${Constants.CURRENCY_NAME}${data.stats.totalRevenue.toStringAsFixed(2)}', '${Constants.CURRENCY_NAME}${data.stats.todayRevenue.toStringAsFixed(2)}'],
//       ['Total Sales', data.stats.totalSales.toString(), data.stats.todaySales.toString()],
//       ['Total Customers', data.stats.totalCustomers.toString(), data.stats.todayCustomers.toString()],
//       ['Average Order Value', '${Constants.CURRENCY_NAME}${data.stats.averageOrderValue.toStringAsFixed(2)}', '-'],
//       ['Conversion Rate', '${data.stats.conversionRate.toStringAsFixed(1)}%', '-'],
//       ['Low Stock Products', data.stats.lowStockProducts.toString(), '-'],
//     ];
//
//     final PdfGrid statsGrid = PdfGrid();
//     statsGrid.columns.add(count: 3);
//     statsGrid.headers.add(1);
//
//     for (int i = 0; i < statsTable.length; i++) {
//       final PdfGridRow row = statsGrid.rows.add();
//       for (int j = 0; j < 3; j++) {
//         row.cells[j].value = statsTable[i][j];
//         row.cells[j].style.font = bodyFont;
//         if (i == 0) {
//           row.cells[j].style.backgroundBrush = PdfBrushes.lightBlue;
//         }
//       }
//     }
//
//     statsGrid.draw(
//       page: page,
//       bounds: Rect.fromLTWH(50, y, page.getClientSize().width - 100, 0),
//     );
//
//     y += statsGrid.rows.count * 25 + 40;
//
//     // Revenue Data
//     if (data.revenueData.isNotEmpty) {
//       graphics.drawString(
//         'Revenue Trend (Last 7 Days)',
//         titleFont,
//         brush: PdfBrushes.darkBlue,
//         bounds: Rect.fromLTWH(50, y, page.getClientSize().width - 100, 30),
//       );
//
//       y += 40;
//
//       final List<List<String>> revenueTable = [
//         ['Date', 'Revenue', 'Orders'],
//       ];
//
//       for (final point in data.revenueData) {
//         revenueTable.add([
//           DateFormat('MMM d').format(point.date),
//           '${Constants.CURRENCY_NAME}${point.revenue.toStringAsFixed(2)}',
//           point.orders.toString(),
//         ]);
//       }
//
//       final PdfGrid revenueGrid = PdfGrid();
//       revenueGrid.columns.add(count: 3);
//       revenueGrid.headers.add(1);
//
//       for (int i = 0; i < revenueTable.length; i++) {
//         final PdfGridRow row = revenueGrid.rows.add();
//         for (int j = 0; j < 3; j++) {
//           row.cells[j].value = revenueTable[i][j];
//           row.cells[j].style.font = bodyFont;
//           if (i == 0) {
//             row.cells[j].style.backgroundBrush = PdfBrushes.lightBlue;
//           }
//         }
//       }
//
//       revenueGrid.draw(
//         page: page,
//         bounds: Rect.fromLTWH(50, y, page.getClientSize().width - 100, 0),
//       );
//
//       y += revenueGrid.rows.count * 25 + 40;
//     }
//
//     // Save PDF
//     final Directory directory = await getApplicationDocumentsDirectory();
//     final String path = '${directory.path}/dashboard_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
//     final File file = File(path);
//     await file.writeAsBytes(await document.save());
//     document.dispose();
//
//     return path;
//   }
//
//   static Future<String> exportToCSV(EnhancedDashboardData data) async {
//     final List<List<dynamic>> csvData = [];
//
//     // Header
//     csvData.add(['Dashboard Export', 'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(data.lastUpdated)}']);
//     csvData.add([]);
//
//     // Stats
//     csvData.add(['Business Performance']);
//     csvData.add(['Metric', 'Value', 'Today']);
//     csvData.add(['Total Revenue', data.stats.totalRevenue, data.stats.todayRevenue]);
//     csvData.add(['Total Sales', data.stats.totalSales, data.stats.todaySales]);
//     csvData.add(['Total Customers', data.stats.totalCustomers, data.stats.todayCustomers]);
//     csvData.add(['Average Order Value', data.stats.averageOrderValue, '']);
//     csvData.add(['Conversion Rate', data.stats.conversionRate, '']);
//     csvData.add(['Low Stock Products', data.stats.lowStockProducts, '']);
//     csvData.add(['Total Returns', data.stats.totalReturns, data.stats.todayReturns]);
//     csvData.add([]);
//
//     // Revenue Data
//     if (data.revenueData.isNotEmpty) {
//       csvData.add(['Revenue Trend (Last 7 Days)']);
//       csvData.add(['Date', 'Revenue', 'Orders']);
//       for (final point in data.revenueData) {
//         csvData.add([
//           DateFormat('yyyy-MM-dd').format(point.date),
//           point.revenue,
//           point.orders,
//         ]);
//       }
//       csvData.add([]);
//     }
//
//     // Category Distribution
//     if (data.categoryDistribution.isNotEmpty) {
//       csvData.add(['Category Performance']);
//       csvData.add(['Category', 'Revenue', 'Orders', 'Percentage']);
//       for (final cat in data.categoryDistribution) {
//         csvData.add([
//           cat.categoryName,
//           cat.revenue,
//           cat.orders,
//           cat.percentage,
//         ]);
//       }
//       csvData.add([]);
//     }
//
//     // Payment Methods
//     if (data.paymentMethods.isNotEmpty) {
//       csvData.add(['Payment Methods']);
//       csvData.add(['Method', 'Transactions', 'Amount', 'Percentage']);
//       for (final method in data.paymentMethods) {
//         csvData.add([
//           method.method,
//           method.count,
//           method.amount,
//           method.percentage,
//         ]);
//       }
//     }
//
//     final String csv = const ListToCsvConverter().convert(csvData);
//     final Directory directory = await getApplicationDocumentsDirectory();
//     final String path = '${directory.path}/dashboard_export_${DateTime.now().millisecondsSinceEpoch}.csv';
//     final File file = File(path);
//     await file.writeAsString(csv);
//
//     return path;
//   }
//
//   static Future<void> shareReport(EnhancedDashboardData data, BuildContext context) async {
//     try {
//       final String pdfPath = await exportToPDF(data);
//       final String csvPath = await exportToCSV(data);
//
//       await Share.shareXFiles(
//         [
//           XFile(pdfPath, mimeType: 'application/pdf'),
//           XFile(csvPath, mimeType: 'text/csv'),
//         ],
//         text: 'Dashboard Report - ${DateFormat('yyyy-MM-dd').format(data.lastUpdated)}',
//         subject: 'Business Dashboard Report',
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to share report: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
// }
//
// class DashboardSyncService {
//   final LocalDatabase _localDb = LocalDatabase();
//   final Connectivity _connectivity = Connectivity();
//   final EnhancedPOSService _posService = EnhancedPOSService();
//
//   static final DashboardSyncService _instance = DashboardSyncService._internal();
//   factory DashboardSyncService() => _instance;
//   DashboardSyncService._internal();
//
//   Future<EnhancedDashboardData> generateDashboardData(String tenantId) async {
//     try {
//       // Get all local data
//       final pendingOrders = await _localDb.getPendingOrders();
//       final syncedOrders = await _getAllSyncedOrders();
//       final allOrders = [...pendingOrders, ...syncedOrders];
//
//       final products = await _localDb.getAllProducts();
//       final customers = await _localDb.getCustomers();
//       final pendingReturns = await _localDb.getPendingReturns();
//       final syncedReturns = await _localDb.getSyncedReturns();
//       final allReturns = [...pendingReturns, ...syncedReturns.map((r) => r.toLocalMap())];
//
//       final categories = await _localDb.getAllCategories();
//
//       final now = DateTime.now();
//       final todayStart = DateTime(now.year, now.month, now.day);
//       final weekStart = todayStart.subtract(Duration(days: 6));
//
//       // Calculate stats
//       final stats = await _calculateStats(allOrders, products, customers, allReturns, todayStart);
//
//       // Generate revenue data for last 7 days
//       final revenueData = await _generateRevenueData(allOrders, weekStart, now);
//
//       // Generate category distribution
//       final categoryDistribution = await _generateCategoryDistribution(allOrders, categories, weekStart, now);
//
//       // Generate hourly sales data
//       final hourlySales = await _generateHourlySales(allOrders, todayStart);
//
//       // Generate payment method data
//       final paymentMethods = await _generatePaymentMethods(allOrders);
//
//       // Generate customer analytics
//       final customerAnalytics = await _generateCustomerAnalytics(allOrders, customers, todayStart);
//
//       return EnhancedDashboardData(
//         stats: stats,
//         revenueData: revenueData,
//         categoryDistribution: categoryDistribution,
//         hourlySales: hourlySales,
//         paymentMethods: paymentMethods,
//         customerAnalytics: customerAnalytics,
//         lastUpdated: DateTime.now(),
//         tenantId: tenantId,
//         syncStatus: 'offline',
//       );
//     } catch (e) {
//       debugPrint('Error generating dashboard data: $e');
//       return EnhancedDashboardData(
//         stats: DashboardStats.empty(),
//         revenueData: [],
//         categoryDistribution: [],
//         hourlySales: [],
//         paymentMethods: [],
//         customerAnalytics: CustomerAnalytics(
//           newCustomers: 0,
//           returningCustomers: 0,
//           customerGrowth: 0.0,
//           retentionRate: 0.0,
//           averageCustomerValue: 0.0,
//         ),
//         lastUpdated: DateTime.now(),
//         tenantId: tenantId,
//         syncStatus: 'error',
//       );
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> _getAllSyncedOrders() async {
//     try {
//       // In a real implementation, this would fetch from Firestore
//       // For now, return empty since we're focusing on offline
//       return [];
//     } catch (e) {
//       debugPrint('Error getting synced orders: $e');
//       return [];
//     }
//   }
//
//   Future<DashboardStats> _calculateStats(
//       List<Map<String, dynamic>> orders,
//       List<Product> products,
//       List<Customer> customers,
//       List<Map<String, dynamic>> returns,
//       DateTime todayStart,
//       ) async {
//     double todayRevenue = 0.0;
//     int todaySales = 0;
//     final todayCustomerIds = <String>{};
//     double totalRevenue = 0.0;
//
//     for (final order in orders) {
//       final orderDate = DateTime.parse(order['created_at']);
//       final orderData = order['order_data'] as Map<String, dynamic>;
//       final orderTotal = (orderData['total'] as num?)?.toDouble() ?? 0.0;
//
//       totalRevenue += orderTotal;
//
//       if (orderDate.isAfter(todayStart)) {
//         todayRevenue += orderTotal;
//         todaySales++;
//
//         final customerData = order['customer_data'] as Map<String, dynamic>?;
//         if (customerData != null && customerData['customerId'] != null) {
//           todayCustomerIds.add(customerData['customerId'].toString());
//         }
//       }
//     }
//
//     final lowStockProducts = products.where((p) => p.stockQuantity <= 10).length;
//
//     final averageOrderValue = orders.isNotEmpty
//         ? totalRevenue / orders.length
//         : 0.0;
//
//     final conversionRate = customers.isNotEmpty
//         ? (orders.length / customers.length * 100).clamp(0.0, 100.0)
//         : 0.0;
//
//     final todayReturns = returns.where((returnReq) {
//       final returnDate = DateTime.parse(returnReq['created_at'] ?? '');
//       return returnDate.isAfter(todayStart);
//     }).length;
//
//     // Calculate growth (simple implementation - in real app, compare with previous period)
//     final revenueGrowth = 0.0; // Would need historical data
//     final salesGrowth = 0.0; // Would need historical data
//
//     return DashboardStats(
//       totalRevenue: totalRevenue,
//       todayRevenue: todayRevenue,
//       totalSales: orders.length,
//       todaySales: todaySales,
//       totalProducts: products.length,
//       lowStockProducts: lowStockProducts,
//       totalCustomers: customers.length,
//       todayCustomers: todayCustomerIds.length,
//       averageOrderValue: averageOrderValue,
//       conversionRate: conversionRate,
//       revenueGrowth: revenueGrowth,
//       salesGrowth: salesGrowth,
//       todayReturns: todayReturns,
//       totalReturns: returns.length,
//     );
//   }
//
//   Future<List<RevenueDataPoint>> _generateRevenueData(
//       List<Map<String, dynamic>> orders,
//       DateTime startDate,
//       DateTime endDate,
//       ) async {
//     final List<RevenueDataPoint> revenueData = [];
//     final Map<String, double> dailyRevenue = {};
//     final Map<String, int> dailyOrders = {};
//
//     for (final order in orders) {
//       final orderDate = DateTime.parse(order['created_at']);
//       if (orderDate.isBefore(startDate) || orderDate.isAfter(endDate)) continue;
//
//       final dateKey = DateFormat('yyyy-MM-dd').format(orderDate);
//       final orderData = order['order_data'] as Map<String, dynamic>;
//       final orderTotal = (orderData['total'] as num?)?.toDouble() ?? 0.0;
//
//       dailyRevenue.update(dateKey, (value) => value + orderTotal, ifAbsent: () => orderTotal);
//       dailyOrders.update(dateKey, (value) => value + 1, ifAbsent: () => 1);
//     }
//
//     // Generate data for all dates in range
//     DateTime currentDate = startDate;
//     while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
//       final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
//       revenueData.add(RevenueDataPoint(
//         date: currentDate,
//         revenue: dailyRevenue[dateKey] ?? 0.0,
//         orders: dailyOrders[dateKey] ?? 0,
//       ));
//       currentDate = currentDate.add(Duration(days: 1));
//     }
//
//     return revenueData;
//   }
//
//   Future<List<CategoryDistribution>> _generateCategoryDistribution(
//       List<Map<String, dynamic>> orders,
//       List<Category> categories,
//       DateTime startDate,
//       DateTime endDate,
//       ) async {
//     final Map<String, double> categoryRevenue = {};
//     final Map<String, int> categoryOrders = {};
//     double totalRevenue = 0.0;
//
//     for (final order in orders) {
//       final orderDate = DateTime.parse(order['created_at']);
//       if (orderDate.isBefore(startDate) || orderDate.isAfter(endDate)) continue;
//
//       final orderData = order['order_data'] as Map<String, dynamic>;
//       final orderTotal = (orderData['total'] as num?)?.toDouble() ?? 0.0;
//       totalRevenue += orderTotal;
//
//       // In real implementation, you'd map products to categories
//       // For now, using a simplified approach
//       final categoryName = 'General'; // Default category
//       categoryRevenue.update(categoryName, (value) => value + orderTotal, ifAbsent: () => orderTotal);
//       categoryOrders.update(categoryName, (value) => value + 1, ifAbsent: () => 1);
//     }
//
//     return categoryRevenue.entries.map((entry) {
//       final percentage = totalRevenue > 0 ? (entry.value / totalRevenue * 100) : 0.0;
//       return CategoryDistribution(
//         categoryName: entry.key,
//         revenue: entry.value,
//         orders: categoryOrders[entry.key] ?? 0,
//         percentage: percentage,
//       );
//     }).toList();
//   }
//
//   Future<List<HourlySalesData>> _generateHourlySales(
//       List<Map<String, dynamic>> orders,
//       DateTime todayStart,
//       ) async {
//     final Map<int, double> hourlyRevenue = {};
//     final Map<int, int> hourlyOrders = {};
//
//     for (final order in orders) {
//       final orderDate = DateTime.parse(order['created_at']);
//       if (!orderDate.isAfter(todayStart)) continue;
//
//       final hour = orderDate.hour;
//       final orderData = order['order_data'] as Map<String, dynamic>;
//       final orderTotal = (orderData['total'] as num?)?.toDouble() ?? 0.0;
//
//       hourlyRevenue.update(hour, (value) => value + orderTotal, ifAbsent: () => orderTotal);
//       hourlyOrders.update(hour, (value) => value + 1, ifAbsent: () => 1);
//     }
//
//     final List<HourlySalesData> hourlySales = [];
//     for (int hour = 0; hour < 24; hour++) {
//       hourlySales.add(HourlySalesData(
//         hour: hour,
//         revenue: hourlyRevenue[hour] ?? 0.0,
//         orders: hourlyOrders[hour] ?? 0,
//       ));
//     }
//
//     return hourlySales;
//   }
//
//   Future<List<PaymentMethodData>> _generatePaymentMethods(
//       List<Map<String, dynamic>> orders,
//       ) async {
//     final Map<String, int> methodCount = {};
//     final Map<String, double> methodAmount = {};
//     int totalTransactions = 0;
//     double totalAmount = 0.0;
//
//     for (final order in orders) {
//       final paymentData = order['payment_data'] as Map<String, dynamic>?;
//       final method = paymentData?['method']?.toString() ?? 'cash';
//       final amount = (paymentData?['amount_paid'] as num?)?.toDouble() ?? 0.0;
//
//       methodCount.update(method, (value) => value + 1, ifAbsent: () => 1);
//       methodAmount.update(method, (value) => value + amount, ifAbsent: () => amount);
//       totalTransactions++;
//       totalAmount += amount;
//     }
//
//     return methodCount.entries.map((entry) {
//       final amount = methodAmount[entry.key] ?? 0.0;
//       final percentage = totalTransactions > 0 ? (entry.value / totalTransactions * 100) : 0.0;
//       return PaymentMethodData(
//         method: entry.key,
//         count: entry.value,
//         amount: amount,
//         percentage: percentage,
//       );
//     }).toList();
//   }
//
//   Future<CustomerAnalytics> _generateCustomerAnalytics(
//       List<Map<String, dynamic>> orders,
//       List<Customer> customers,
//       DateTime todayStart,
//       ) async {
//     int newCustomers = 0;
//     int returningCustomers = 0;
//     double totalCustomerValue = 0.0;
//
//     // In real implementation, you'd track customer order history
//     // For now, using simplified logic
//     final Map<String, int> customerOrderCount = {};
//
//     for (final order in orders) {
//       final customerData = order['customer_data'] as Map<String, dynamic>?;
//       if (customerData == null) continue;
//
//       final customerId = customerData['customerId']?.toString();
//       if (customerId == null) continue;
//
//       final orderDate = DateTime.parse(order['created_at']);
//       final isToday = orderDate.isAfter(todayStart);
//
//       customerOrderCount.update(customerId, (value) => value + 1, ifAbsent: () => 1);
//
//       if (isToday) {
//         if (customerOrderCount[customerId] == 1) {
//           newCustomers++;
//         } else {
//           returningCustomers++;
//         }
//       }
//
//       final orderData = order['order_data'] as Map<String, dynamic>;
//       final orderTotal = (orderData['total'] as num?)?.toDouble() ?? 0.0;
//       totalCustomerValue += orderTotal;
//     }
//
//     final averageCustomerValue = customers.isNotEmpty
//         ? totalCustomerValue / customers.length
//         : 0.0;
//
//     // Simplified retention calculation
//     final retentionRate = newCustomers > 0
//         ? (returningCustomers / newCustomers * 100).clamp(0.0, 100.0)
//         : 0.0;
//
//     return CustomerAnalytics(
//       newCustomers: newCustomers,
//       returningCustomers: returningCustomers,
//       customerGrowth: 0.0, // Would need historical comparison
//       retentionRate: retentionRate,
//       averageCustomerValue: averageCustomerValue,
//     );
//   }
//
//   Future<void> syncWithServer(String tenantId) async {
//     final connectivityResult = await _connectivity.checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       throw Exception('No internet connection available');
//     }
//
//     try {
//       // Generate local data
//       final localData = await generateDashboardData(tenantId);
//
//       // In real implementation, you would:
//       // 1. Fetch server data
//       // 2. Merge with local data
//       // 3. Upload merged data
//       // 4. Update local cache with server timestamp
//
//       debugPrint('Dashboard sync completed successfully');
//     } catch (e) {
//       debugPrint('Dashboard sync failed: $e');
//       throw Exception('Failed to sync dashboard data: $e');
//     }
//   }
// }