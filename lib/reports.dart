// // Add these imports at the top of your file
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:flutter/material.dart';
// import 'package:mpcm/app.dart' hide Order;
//
// import 'constants.dart';
// // Analytics Data Models
// class SalesAnalytics {
//   final double totalSales;
//   final int totalOrders;
//   final int totalItemsSold;
//   final double averageOrderValue;
//   final Map<String, double> salesByHour;
//   final Map<String, double> salesByDay;
//   final List<ProductPerformance> topProducts;
//   final List<CategoryPerformance> topCategories;
//
//   SalesAnalytics({
//     required this.totalSales,
//     required this.totalOrders,
//     required this.totalItemsSold,
//     required this.averageOrderValue,
//     required this.salesByHour,
//     required this.salesByDay,
//     required this.topProducts,
//     required this.topCategories,
//   });
// }
//
// class ProductPerformance {
//   final Product product;
//   final int quantitySold;
//   final double revenue;
//   final double percentage;
//
//   ProductPerformance({
//     required this.product,
//     required this.quantitySold,
//     required this.revenue,
//     required this.percentage,
//   });
// }
//
// class CategoryPerformance {
//   final Category category;
//   final int quantitySold;
//   final double revenue;
//   final double percentage;
//
//   CategoryPerformance({
//     required this.category,
//     required this.quantitySold,
//     required this.revenue,
//     required this.percentage,
//   });
// }
//
// class TimePeriod {
//   final String label;
//   final DateTime startDate;
//   final DateTime endDate;
//
//   TimePeriod({
//     required this.label,
//     required this.startDate,
//     required this.endDate,
//   });
// }
//
// // Analytics Service
// class AnalyticsService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   Future<SalesAnalytics> getSalesAnalytics(TimePeriod period) async {
//     try {
//       // Get orders within the time period
//       final ordersSnapshot = await _firestore
//           .collection('orders')
//           .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
//           .where('dateCreated', isLessThanOrEqualTo: period.endDate)
//           .get();
//
//       final orders = ordersSnapshot.docs.map((doc) {
//         final data = doc.data();
//         return Order.fromFirestore(data, doc.id);
//       }).toList();
//
//       // Calculate analytics
//       final totalSales = orders.fold(0.0, (sum, order) => sum + order.total);
//       final totalOrders = orders.length;
//       final totalItemsSold = orders.fold(0, (sum, order) {
//         return sum + (order.lineItems as List).fold(0, (itemSum, item) {
//           final itemMap = item as Map<String, dynamic>;
//           return itemSum + (itemMap['quantity'] as int);
//         });
//       });
//
//       final averageOrderValue = totalOrders > 0 ? totalSales / totalOrders : 0;
//
//       // Sales by hour
//       final salesByHour = <String, double>{};
//       for (int hour = 0; hour < 24; hour++) {
//         final hourSales = orders.where((order) {
//           return order.dateCreated.hour == hour;
//         }).fold(0.0, (sum, order) => sum + order.total);
//         salesByHour['${hour.toString().padLeft(2, '0')}:00'] = hourSales;
//       }
//
//       // Sales by day
//       final salesByDay = <String, double>{};
//       final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//       for (final day in days) {
//         salesByDay[day] = 0.0;
//       }
//
//       for (final order in orders) {
//         final dayName = DateFormat('E').format(order.dateCreated);
//         salesByDay[dayName] = (salesByDay[dayName] ?? 0) + order.total;
//       }
//
//       // Top products
//       final productSales = <String, Map<String, dynamic>>{};
//       for (final order in orders) {
//         for (final item in order.lineItems as List) {
//           final itemMap = item as Map<String, dynamic>;
//           final productId = itemMap['productId'].toString();
//           final quantity = itemMap['quantity'] as int;
//           final price = (itemMap['price'] as num).toDouble();
//
//           if (!productSales.containsKey(productId)) {
//             productSales[productId] = {
//               'product': await _getProductById(productId),
//               'quantity': 0,
//               'revenue': 0.0,
//             };
//           }
//
//           productSales[productId]!['quantity'] += quantity;
//           productSales[productId]!['revenue'] += quantity * price;
//         }
//       }
//
//       final topProducts = productSales.values
//           .where((data) => data['product'] != null)
//           .map((data) => ProductPerformance(
//         product: data['product'] as Product,
//         quantitySold: data['quantity'] as int,
//         revenue: data['revenue'] as double,
//         percentage: totalSales > 0 ? (data['revenue'] as double) / totalSales * 100 : 0,
//       ))
//           .toList()
//         ..sort((a, b) => b.revenue.compareTo(a.revenue));
//
//       // Top categories (simplified - you might want to enhance this)
//       final topCategories = <CategoryPerformance>[];
//
//       return SalesAnalytics(
//         totalSales: totalSales,
//         totalOrders: totalOrders,
//         totalItemsSold: totalItemsSold,
//         averageOrderValue: averageOrderValue,
//         salesByHour: salesByHour,
//         salesByDay: salesByDay,
//         topProducts: topProducts.take(5).toList(),
//         topCategories: topCategories,
//       );
//     } catch (e) {
//       throw Exception('Failed to fetch analytics: $e');
//     }
//   }
//
//   Future<Product?> _getProductById(String productId) async {
//     try {
//       final doc = await _firestore.collection('products').doc(productId).get();
//       if (doc.exists) {
//         return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
//       }
//       return null;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   // Get recent orders for the dashboard
//   Future<List<Order>> getRecentOrders({int limit = 10}) async {
//     final snapshot = await _firestore
//         .collection('orders')
//         .orderBy('dateCreated', descending: true)
//         .limit(limit)
//         .get();
//
//     return snapshot.docs.map((doc) {
//       return Order.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
//     }).toList();
//   }
//
//   // Get cash summary
//   Future<Map<String, dynamic>> getCashSummary(TimePeriod period) async {
//     final analytics = await getSalesAnalytics(period);
//
//     return {
//       'totalCash': analytics.totalSales,
//       'cashOrders': analytics.totalOrders,
//       'averageTransaction': analytics.averageOrderValue,
//       'peakHour': _findPeakHour(analytics.salesByHour),
//     };
//   }
//
//   String _findPeakHour(Map<String, double> salesByHour) {
//     if (salesByHour.isEmpty) return 'N/A';
//
//     var peakHour = salesByHour.entries.first;
//     for (final entry in salesByHour.entries) {
//       if (entry.value > peakHour.value) {
//         peakHour = entry;
//       }
//     }
//     return peakHour.key;
//   }
// }
//
// // Analytics Dashboard Screen
// class AnalyticsDashboardScreen extends StatefulWidget {
//   @override
//   _AnalyticsDashboardScreenState createState() => _AnalyticsDashboardScreenState();
// }
//
// class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> with SingleTickerProviderStateMixin {
//   final AnalyticsService _analyticsService = AnalyticsService();
//   final EnhancedPOSService _posService = EnhancedPOSService();
//
//   TimePeriod _selectedPeriod = TimePeriods.today;
//   SalesAnalytics? _analytics;
//   List<Order> _recentOrders = [];
//   Map<String, dynamic> _cashSummary = {};
//   bool _isLoading = true;
//   bool _hasError = false;
//   String _errorMessage = '';
//
//   late TabController _tabController;
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//     _loadAnalytics();
//   }
//
//   Future<void> _loadAnalytics() async {
//     setState(() {
//       _isLoading = true;
//       _hasError = false;
//     });
//
//     try {
//       final [analytics, recentOrders, cashSummary] = await Future.wait([
//         _analyticsService.getSalesAnalytics(_selectedPeriod),
//         _analyticsService.getRecentOrders(),
//         _analyticsService.getCashSummary(_selectedPeriod),
//       ]);
//
//       setState(() {
//         _analytics = analytics;
//         _recentOrders = recentOrders;
//         _cashSummary = cashSummary;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _hasError = true;
//         _errorMessage = e.toString();
//         _isLoading = false;
//       });
//     }
//   }
//
//   void _onPeriodChanged(TimePeriod period) {
//     setState(() {
//       _selectedPeriod = period;
//     });
//     _loadAnalytics();
//   }
//
//   Widget _buildPeriodSelector() {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black12,
//             blurRadius: 8,
//             offset: Offset(0, 2),
//           ),
//         ],
//       ),
//       child: DropdownButton<TimePeriod>(
//         value: _selectedPeriod,
//         isExpanded: true,
//         underline: SizedBox(),
//         items: TimePeriods.allPeriods.map((period) {
//           return DropdownMenuItem<TimePeriod>(
//             value: period,
//             child: Text(
//               period.label,
//               style: TextStyle(fontWeight: FontWeight.w500),
//             ),
//           );
//         }).toList(),
//         onChanged: (period) => _onPeriodChanged(period!),
//       ),
//     );
//   }
//
//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(strokeWidth: 3),
//           SizedBox(height: 16),
//           Text(
//             'Loading Analytics...',
//             style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildErrorState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.error_outline, size: 64, color: Colors.red),
//           SizedBox(height: 16),
//           Text(
//             'Failed to load analytics',
//             style: TextStyle(fontSize: 18, color: Colors.grey[800]),
//           ),
//           SizedBox(height: 8),
//           Text(
//             _errorMessage,
//             style: TextStyle(color: Colors.grey[600]),
//             textAlign: TextAlign.center,
//           ),
//           SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: _loadAnalytics,
//             icon: Icon(Icons.refresh),
//             label: Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         title: Text('Analytics Dashboard'),
//         backgroundColor: Colors.blue[700],
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadAnalytics,
//             tooltip: 'Refresh',
//           ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           labelColor: Colors.white,
//           unselectedLabelColor: Colors.white70,
//           indicatorColor: Colors.white,
//           tabs: [
//             Tab(text: 'Overview'),
//             Tab(text: 'Sales'),
//             Tab(text: 'Products'),
//           ],
//         ),
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: EdgeInsets.all(16),
//             child: _buildPeriodSelector(),
//           ),
//           Expanded(
//             child: _isLoading
//                 ? _buildLoadingState()
//                 : _hasError
//                 ? _buildErrorState()
//                 : TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildOverviewTab(),
//                 _buildSalesTab(),
//                 _buildProductsTab(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildOverviewTab() {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         children: [
//           // Key Metrics
//           _buildKeyMetrics(),
//           SizedBox(height: 20),
//
//           // Recent Orders
//           _buildRecentOrders(),
//           SizedBox(height: 20),
//
//           // Cash Summary
//           _buildCashSummary(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildKeyMetrics() {
//     return GridView.count(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       crossAxisCount: 2,
//       crossAxisSpacing: 16,
//       mainAxisSpacing: 16,
//       children: [
//         _buildMetricCard(
//           title: 'Total Sales',
//           value: '${Constants.CURRENCY_NAME}${_analytics?.totalSales.toStringAsFixed(0) ?? '0'}',
//           icon: Icons.attach_money,
//           color: Colors.green,
//         ),
//         _buildMetricCard(
//           title: 'Total Orders',
//           value: '${_analytics?.totalOrders ?? 0}',
//           icon: Icons.shopping_cart,
//           color: Colors.blue,
//         ),
//         _buildMetricCard(
//           title: 'Items Sold',
//           value: '${_analytics?.totalItemsSold ?? 0}',
//           icon: Icons.inventory,
//           color: Colors.orange,
//         ),
//         _buildMetricCard(
//           title: 'Avg Order',
//           value: '${Constants.CURRENCY_NAME}${_analytics?.averageOrderValue.toStringAsFixed(0) ?? '0'}',
//           icon: Icons.analytics,
//           color: Colors.purple,
//         ),
//       ],
//     );
//   }
//
//   Widget _buildMetricCard({
//     required String title,
//     required String value,
//     required IconData icon,
//     required Color color,
//   }) {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Container(
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(icon, color: color, size: 20),
//                 ),
//               ],
//             ),
//             SizedBox(height: 12),
//             Text(
//               title,
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey[600],
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             SizedBox(height: 4),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.grey[800],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRecentOrders() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.receipt, color: Colors.blue),
//                 SizedBox(width: 8),
//                 Text(
//                   'Recent Orders',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 Spacer(),
//                 Text(
//                   '${_recentOrders.length} orders',
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             ..._recentOrders.take(5).map((order) => _buildOrderListItem(order)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildOrderListItem(Order order) {
//     return Container(
//       margin: EdgeInsets.only(bottom: 12),
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.grey[50],
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: Colors.green[100],
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Icon(Icons.receipt_long, color: Colors.green),
//           ),
//           SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Order #${order.number}',
//                   style: TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   DateFormat('MMM dd, yyyy - HH:mm').format(order.dateCreated),
//                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                 ),
//               ],
//             ),
//           ),
//           Text(
//             '${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(0)}',
//             style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCashSummary() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.money, color: Colors.green),
//                 SizedBox(width: 8),
//                 Text(
//                   'Cash Summary',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             Row(
//               children: [
//                 _buildCashMetric(
//                   'Total Cash',
//                   '${Constants.CURRENCY_NAME}${_cashSummary['totalCash']?.toStringAsFixed(0) ?? '0'}',
//                 ),
//                 _buildCashMetric(
//                   'Transactions',
//                   '${_cashSummary['cashOrders'] ?? 0}',
//                 ),
//               ],
//             ),
//             SizedBox(height: 12),
//             Row(
//               children: [
//                 _buildCashMetric(
//                   'Avg Transaction',
//                   '${Constants.CURRENCY_NAME}${_cashSummary['averageTransaction']?.toStringAsFixed(0) ?? '0'}',
//                 ),
//                 _buildCashMetric(
//                   'Peak Hour',
//                   _cashSummary['peakHour'] ?? 'N/A',
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCashMetric(String label, String value) {
//     return Expanded(
//       child: Container(
//         margin: EdgeInsets.all(4),
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.grey[50],
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Text(
//               label,
//               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//               textAlign: TextAlign.center,
//             ),
//             SizedBox(height: 4),
//             Text(
//               value,
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSalesTab() {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         children: [
//           // Sales Trends
//           _buildSalesTrendsChart(),
//           SizedBox(height: 20),
//
//           // Hourly Sales
//           _buildHourlySalesChart(),
//           SizedBox(height: 20),
//
//           // Daily Sales
//           _buildDailySalesChart(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSalesTrendsChart() {
//     // This would typically show sales over time
//     // For now, we'll show a placeholder
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Sales Trends',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               height: 200,
//               child: Center(
//                 child: Text(
//                   'Sales trends chart would appear here\n(Requires more historical data)',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHourlySalesChart() {
//     final hourlyData = _analytics?.salesByHour.entries.map((entry) {
//       return ChartData(entry.key, entry.value);
//     }).toList() ?? [];
//
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Sales by Hour',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               height: 300,
//               child: SfCartesianChart(
//                 primaryXAxis: CategoryAxis(),
//                 series: <ColumnSeries<ChartData, String>>[
//                   ColumnSeries<ChartData, String>(
//                     dataSource: hourlyData,
//                     xValueMapper: (ChartData data, _) => data.x,
//                     yValueMapper: (ChartData data, _) => data.y,
//                     color: Colors.blue[400],
//                     dataLabelSettings: DataLabelSettings(
//                       isVisible: true,
//                       labelAlignment: ChartDataLabelAlignment.outer,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDailySalesChart() {
//     final dailyData = _analytics?.salesByDay.entries.map((entry) {
//       return ChartData(entry.key, entry.value);
//     }).toList() ?? [];
//
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Sales by Day',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               height: 300,
//               child: SfCartesianChart(
//                 primaryXAxis: CategoryAxis(),
//                 series: <ColumnSeries<ChartData, String>>[
//                   ColumnSeries<ChartData, String>(
//                     dataSource: dailyData,
//                     xValueMapper: (ChartData data, _) => data.x,
//                     yValueMapper: (ChartData data, _) => data.y,
//                     color: Colors.green[400],
//                     dataLabelSettings: DataLabelSettings(
//                       isVisible: true,
//                       labelAlignment: ChartDataLabelAlignment.outer,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildProductsTab() {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         children: [
//           // Top Products
//           _buildTopProducts(),
//           SizedBox(height: 20),
//
//           // Product Performance
//           _buildProductPerformance(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTopProducts() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.star, color: Colors.amber),
//                 SizedBox(width: 8),
//                 Text(
//                   'Top Performing Products',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             SizedBox(height: 16),
//             ..._analytics?.topProducts.map((product) => _buildProductPerformanceItem(product)) ?? [
//               Center(
//                 child: Text(
//                   'No product data available',
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildProductPerformanceItem(ProductPerformance performance) {
//     return Container(
//       margin: EdgeInsets.only(bottom: 12),
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.grey[50],
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: BorderRadius.circular(8),
//               image: performance.product.imageUrl != null
//                   ? DecorationImage(
//                 image: NetworkImage(performance.product.imageUrl!),
//                 fit: BoxFit.cover,
//               )
//                   : null,
//             ),
//             child: performance.product.imageUrl == null
//                 ? Icon(Icons.shopping_bag, color: Colors.grey[400])
//                 : null,
//           ),
//           SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   performance.product.name,
//                   style: TextStyle(fontWeight: FontWeight.w600),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   '${performance.quantitySold} sold • ${Constants.CURRENCY_NAME}${performance.revenue.toStringAsFixed(0)}',
//                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                 ),
//               ],
//             ),
//           ),
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: Colors.blue[50],
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Text(
//               '${performance.percentage.toStringAsFixed(1)}%',
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.blue[700],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildProductPerformance() {
//     final productData = _analytics?.topProducts.map((p) {
//       return ChartData(p.product.name, p.revenue);
//     }).toList() ?? [];
//
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Product Revenue Distribution',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//             Container(
//               height: 300,
//               child: SfCircularChart(
//                 series: <PieSeries<ChartData, String>>[
//                   PieSeries<ChartData, String>(
//                     dataSource: productData,
//                     xValueMapper: (ChartData data, _) => data.x,
//                     yValueMapper: (ChartData data, _) => data.y,
//                     dataLabelMapper: (ChartData data, _) => '${data.x}\n${Constants.CURRENCY_NAME}${data.y.toStringAsFixed(0)}',
//                     dataLabelSettings: DataLabelSettings(isVisible: true),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
// }
//
// // Chart Data Model
// class ChartData {
//   final String x;
//   final double y;
//
//   ChartData(this.x, this.y);
// }
//
// // Time Periods Utility
// class TimePeriods {
//   static final today = TimePeriod(
//     label: 'Today',
//     startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
//     endDate: DateTime.now(),
//   );
//
//   static final yesterday = TimePeriod(
//     label: 'Yesterday',
//     startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
//     endDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1, 23, 59, 59),
//   );
//
//   static final thisWeek = TimePeriod(
//     label: 'This Week',
//     startDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
//     endDate: DateTime.now(),
//   );
//
//   static final lastWeek = TimePeriod(
//     label: 'Last Week',
//     startDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday + 6)),
//     endDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday)),
//   );
//
//   static final thisMonth = TimePeriod(
//     label: 'This Month',
//     startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
//     endDate: DateTime.now(),
//   );
//
//   static final lastMonth = TimePeriod(
//     label: 'Last Month',
//     startDate: DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
//     endDate: DateTime(DateTime.now().year, DateTime.now().month, 0),
//   );
//
//   static final allPeriods = [today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth];
// }
//
// // Add this to your main screen navigation
// // In MainPOSScreen, add the analytics screen to your navigation
// class MainPOSScreen extends StatefulWidget {
//   @override
//   _MainPOSScreenState createState() => _MainPOSScreenState();
// }
//
// class _MainPOSScreenState extends State<MainPOSScreen> {
//   int _currentIndex = 0;
//   final EnhancedCartManager _cartManager = EnhancedCartManager();
//   final EnhancedPOSService _posService = EnhancedPOSService();
//
//   // ... existing code ...
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // ... existing app bar code ...
//       body: _screens.isEmpty
//           ? Center(child: CircularProgressIndicator())
//           : _screens[_currentIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: (index) => setState(() => _currentIndex = index),
//         items: [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.shopping_bag),
//             label: 'Products',
//           ),
//           BottomNavigationBarItem(
//             icon: Stack(
//               children: [
//                 Icon(Icons.shopping_cart),
//                 // ... cart count badge ...
//               ],
//             ),
//             label: 'Cart',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.analytics),
//             label: 'Analytics',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.inventory),
//             label: 'Manage',
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeApp();
//   }
//
//   Future<void> _initializeApp() async {
//     _posService.initialize();
//     await _cartManager.initialize();
//
//     // Initialize screens including analytics
//     _screens.addAll([
//       ProductsScreen(cartManager: _cartManager),
//       CartScreen(cartManager: _cartManager),
//       AnalyticsDashboardScreen(), // Add analytics screen
//       ProductManagementScreen(),
//     ]);
//     setState(() {});
//   }
// }