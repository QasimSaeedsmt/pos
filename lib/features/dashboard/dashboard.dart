// // enhanced_dashboard_screen.dart
// import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../../constants.dart';
// import '../../modules/auth/providers/auth_provider.dart';
// import '../clientDashboard/client_dashboard.dart';
// import '../connectivityBase/local_db_base.dart';
// import 'n.dart';
//
// class EnhancedDashboardScreen extends StatefulWidget {
//   const EnhancedDashboardScreen({super.key});
//
//   @override
//   _EnhancedDashboardScreenState createState() => _EnhancedDashboardScreenState();
// }
//
// class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen>
//     with SingleTickerProviderStateMixin, WidgetsBindingObserver {
//   final DashboardSyncService _syncService = DashboardSyncService();
//   final LocalDatabase _localDb = LocalDatabase();
//
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//
//   EnhancedDashboardData? _dashboardData;
//   bool _isLoading = true;
//   bool _isRefreshing = false;
//   bool _hasError = false;
//   String? _errorMessage;
//   DateTime? _lastAutoRefresh;
//   Timer? _autoRefreshTimer;
//
//   // Refresh intervals
//   static const Duration _autoRefreshInterval = Duration(minutes: 5);
//   static const Duration _staleDataThreshold = Duration(minutes: 10);
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     _initAnimations();
//     _loadDashboardData();
//     _startAutoRefresh();
//   }
//
//   void _initAnimations() {
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );
//
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Curves.easeInOut,
//       ),
//     );
//
//     _animationController.forward();
//   }
//
//   Future<void> _loadDashboardData() async {
//     if (!mounted) return;
//
//     setState(() {
//       _isLoading = true;
//       _hasError = false;
//       _errorMessage = null;
//     });
//
//     try {
//       final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
//       final currentUser = authProvider.currentUser;
//
//       if (currentUser == null) {
//         throw Exception('User not authenticated');
//       }
//
//       final tenantId = currentUser.tenantId;
//       if (tenantId.isEmpty) {
//         throw Exception('Invalid tenant ID');
//       }
//
//       // Check for cached data first
//       final cachedData = await _getCachedDashboardData(tenantId);
//       if (cachedData != null && !_isDataStale(cachedData.lastUpdated)) {
//         if (mounted) {
//           setState(() {
//             _dashboardData = cachedData;
//             _isLoading = false;
//             _lastAutoRefresh = DateTime.now();
//           });
//         }
//       }
//
//       // Always generate fresh data from local database
//       final freshData = await _syncService.generateDashboardData(tenantId);
//
//       if (mounted) {
//         setState(() {
//           _dashboardData = freshData;
//           _isLoading = false;
//           _lastAutoRefresh = DateTime.now();
//           _hasError = false;
//         });
//       }
//
//       // Cache the fresh data
//       await _cacheDashboardData(freshData);
//
//     } catch (e) {
//       debugPrint('Error loading dashboard data: $e');
//
//       if (mounted) {
//         setState(() {
//           _hasError = true;
//           _errorMessage = e.toString();
//           _isLoading = false;
//         });
//       }
//
//       // Show error to user
//       if (mounted && _dashboardData == null) {
//         _showErrorDialog(e.toString());
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isRefreshing = false;
//         });
//       }
//     }
//   }
//
//   Future<EnhancedDashboardData?> _getCachedDashboardData(String tenantId) async {
//     try {
//       final box = await _localDb.dashboardDataBoxInstance;
//       final timestampBox = await _localDb.dashboardCacheTimestampBoxInstance;
//
//       final dashboardData = box.get(LocalDatabase.dashboardDataKey);
//       final timestamp = timestampBox.get(LocalDatabase.dashboardCacheTimestampKey);
//
//       if (dashboardData == null || timestamp == null) {
//         return null;
//       }
//
//       final data = EnhancedDashboardData.fromJson(dashboardData);
//       if (data.tenantId == tenantId) {
//         return data;
//       }
//
//       return null;
//     } catch (e) {
//       debugPrint('Error getting cached dashboard data: $e');
//       return null;
//     }
//   }
//
//   Future<void> _cacheDashboardData(EnhancedDashboardData data) async {
//     try {
//       final box = await _localDb.dashboardDataBoxInstance;
//       final timestampBox = await _localDb.dashboardCacheTimestampBoxInstance;
//
//       await box.put(LocalDatabase.dashboardDataKey, data.toJson());
//       await timestampBox.put(
//         LocalDatabase.dashboardCacheTimestampKey,
//         DateTime.now().millisecondsSinceEpoch,
//       );
//     } catch (e) {
//       debugPrint('Error caching dashboard data: $e');
//     }
//   }
//
//   bool _isDataStale(DateTime lastUpdated) {
//     return DateTime.now().difference(lastUpdated) > _staleDataThreshold;
//   }
//
//   void _startAutoRefresh() {
//     _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
//       if (mounted && _dashboardData != null && _isDataStale(_dashboardData!.lastUpdated)) {
//         _loadDashboardData();
//       }
//     });
//   }
//
//   Future<void> _refreshData() async {
//     if (_isRefreshing) return;
//
//     setState(() => _isRefreshing = true);
//     await _loadDashboardData();
//   }
//
//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Dashboard Error'),
//         content: Text('Failed to load dashboard data: $message'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Dismiss'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _loadDashboardData();
//             },
//             child: const Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const CircularProgressIndicator(
//             strokeWidth: 3,
//             valueColor: AlwaysStoppedAnimation(Colors.blue),
//           ),
//           const SizedBox(height: 20),
//           Text(
//             'Loading Dashboard Data...',
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.grey[600],
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 8),
//           if (_dashboardData != null)
//             Text(
//               'Updating from local cache',
//               style: TextStyle(fontSize: 12, color: Colors.grey[500]),
//             ),
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
//           Icon(
//             Icons.error_outline,
//             size: 64,
//             color: Colors.red[400],
//           ),
//           const SizedBox(height: 20),
//           Text(
//             'Failed to Load Dashboard',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey[800],
//             ),
//           ),
//           const SizedBox(height: 10),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 32),
//             child: Text(
//               _errorMessage ?? 'Unknown error occurred',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ),
//           const SizedBox(height: 20),
//           ElevatedButton.icon(
//             onPressed: _loadDashboardData,
//             icon: const Icon(Icons.refresh),
//             label: const Text('Retry'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               foregroundColor: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDashboardContent() {
//     if (_dashboardData == null) {
//       return _buildLoadingState();
//     }
//
//     return AnimatedBuilder(
//       animation: _animationController,
//       builder: (context, child) {
//         return Opacity(
//           opacity: _fadeAnimation.value,
//           child: RefreshIndicator(
//             onRefresh: _refreshData,
//             child: CustomScrollView(
//               slivers: [
//                 _buildHeader(),
//                 _buildStatsOverview(),
//                 _buildRevenueChartSection(),
//                 _buildPerformanceMetrics(),
//                 _buildCategoryDistribution(),
//                 _buildHourlySalesChart(),
//                 _buildPaymentMethodsSection(),
//                 _buildCustomerAnalytics(),
//                 _buildDataStatusFooter(),
//                 const SliverToBoxAdapter(child: SizedBox(height: 40)),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   SliverToBoxAdapter _buildHeader() {
//     final auth = FirebaseAuth.instance;
//     final user = auth.currentUser;
//
//     return SliverToBoxAdapter(
//       child: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Colors.blue.shade700,
//               Colors.blue.shade900,
//             ],
//           ),
//           borderRadius: const BorderRadius.only(
//             bottomLeft: Radius.circular(24),
//             bottomRight: Radius.circular(24),
//           ),
//         ),
//         padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Good ${_getGreeting()},',
//                         style: const TextStyle(
//                           color: Colors.white70,
//                           fontSize: 16,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         user?.displayName ?? 'Business Dashboard',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'Real-time Business Intelligence',
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.8),
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Column(
//                   children: [
//                     _buildSyncStatusIndicator(),
//                     const SizedBox(height: 8),
//                     if (_isRefreshing)
//                       const SizedBox(
//                         width: 24,
//                         height: 24,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           color: Colors.white,
//                         ),
//                       )
//                     else
//                       IconButton(
//                         icon: const Icon(Icons.refresh, color: Colors.white),
//                         onPressed: _refreshData,
//                         tooltip: 'Refresh Data',
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             _buildQuickActionsRow(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSyncStatusIndicator() {
//     final status = _dashboardData?.syncStatus ?? 'unknown';
//     final isStale = _dashboardData != null && _isDataStale(_dashboardData!.lastUpdated);
//
//     Color backgroundColor;
//     String statusText;
//
//     if (status == 'synced') {
//       backgroundColor = Colors.green;
//       statusText = 'Synced';
//     } else if (status == 'offline') {
//       backgroundColor = Colors.orange;
//       statusText = 'Offline';
//     } else if (status == 'error') {
//       backgroundColor = Colors.red;
//       statusText = 'Error';
//     } else if (isStale) {
//       backgroundColor = Colors.amber;
//       statusText = 'Stale';
//     } else {
//       backgroundColor = Colors.blue;
//       statusText = 'Loading';
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: backgroundColor,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: backgroundColor.withOpacity(0.3),
//             blurRadius: 8,
//             spreadRadius: 1,
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             statusText,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildQuickActionsRow() {
//     return Row(
//       children: [
//         Expanded(
//           child: _QuickActionButton(
//             icon: Icons.download,
//             label: 'Export',
//             color: Colors.green,
//             onPressed: () => _exportDashboardData(),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: _QuickActionButton(
//             icon: Icons.share,
//             label: 'Share',
//             color: Colors.purple,
//             onPressed: () => _shareDashboardData(),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: _QuickActionButton(
//             icon: Icons.sync,
//             label: 'Sync Now',
//             color: Colors.blue,
//             onPressed: () => _manualSync(),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Future<void> _exportDashboardData() async {
//     if (_dashboardData == null) return;
//
//     try {
//       final path = await DashboardExportService.exportToPDF(_dashboardData!);
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Report exported to: $path'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Export failed: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _shareDashboardData() async {
//     if (_dashboardData == null) return;
//
//     try {
//       await DashboardExportService.shareReport(_dashboardData!, context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Share failed: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _manualSync() async {
//     try {
//       final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
//       final tenantId = authProvider.currentUser?.tenantId ?? '';
//
//       await _syncService.syncWithServer(tenantId);
//       await _loadDashboardData();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Sync completed successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Sync failed: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   SliverToBoxAdapter _buildStatsOverview() {
//     if (_dashboardData == null) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final stats = _dashboardData!.stats;
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: GridView.count(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           crossAxisCount: 2,
//           crossAxisSpacing: 12,
//           mainAxisSpacing: 12,
//           childAspectRatio: 1.2,
//           children: [
//             _StatCard(
//               title: 'Total Revenue',
//               value: '${Constants.CURRENCY_NAME}${stats.totalRevenue.toStringAsFixed(0)}',
//               subtitle: '${Constants.CURRENCY_NAME}${stats.todayRevenue.toStringAsFixed(0)} today',
//               icon: Icons.attach_money,
//               color: Colors.green,
//               trend: stats.revenueGrowth,
//             ),
//             _StatCard(
//               title: 'Total Sales',
//               value: stats.totalSales.toString(),
//               subtitle: '${stats.todaySales} today',
//               icon: Icons.shopping_cart,
//               color: Colors.blue,
//               trend: stats.salesGrowth,
//             ),
//             _StatCard(
//               title: 'Customers',
//               value: stats.totalCustomers.toString(),
//               subtitle: '${stats.todayCustomers} today',
//               icon: Icons.people,
//               color: Colors.purple,
//               trend: 0.0,
//             ),
//             _StatCard(
//               title: 'Conversion',
//               value: '${stats.conversionRate.toStringAsFixed(1)}%',
//               subtitle: 'Customer conversion rate',
//               icon: Icons.trending_up,
//               color: Colors.orange,
//               trend: 0.0,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   SliverToBoxAdapter _buildRevenueChartSection() {
//     if (_dashboardData == null || _dashboardData!.revenueData.isEmpty) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final revenueData = _dashboardData!.revenueData;
//     final weeklyGrowth = _calculateWeeklyGrowth(revenueData);
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Text(
//                     'Revenue Trend (7 Days)',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.grey[800],
//                     ),
//                   ),
//                   const Spacer(),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: weeklyGrowth >= 0
//                           ? Colors.green[50]
//                           : Colors.red[50],
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           weeklyGrowth >= 0
//                               ? Icons.trending_up
//                               : Icons.trending_down,
//                           size: 14,
//                           color: weeklyGrowth >= 0
//                               ? Colors.green[700]
//                               : Colors.red[700],
//                         ),
//                         const SizedBox(width: 4),
//                         Text(
//                           '${weeklyGrowth >= 0 ? '+' : ''}${weeklyGrowth.toStringAsFixed(1)}%',
//                           style: TextStyle(
//                             color: weeklyGrowth >= 0
//                                 ? Colors.green[700]
//                                 : Colors.red[700],
//                             fontSize: 12,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 height: 200,
//                 child: SfCartesianChart(
//                   margin: EdgeInsets.zero,
//                   plotAreaBorderWidth: 0,
//                   primaryXAxis: CategoryAxis(
//                     majorGridLines: const MajorGridLines(width: 0),
//                     labelStyle: const TextStyle(fontSize: 10),
//                   ),
//                   primaryYAxis: NumericAxis(
//                     numberFormat: NumberFormat.compactCurrency(
//                       symbol: Constants.CURRENCY_NAME,
//                     ),
//                     majorGridLines: MajorGridLines(
//                       width: 1,
//                       color: Colors.grey[100],
//                     ),
//                     labelStyle: const TextStyle(fontSize: 10),
//                   ),
//                   series: <CartesianSeries>[
//                     LineSeries<RevenueDataPoint, String>(
//                       dataSource: revenueData,
//                       xValueMapper: (RevenueDataPoint data, _) =>
//                           DateFormat('E').format(data.date),
//                       yValueMapper: (RevenueDataPoint data, _) => data.revenue,
//                       color: Colors.blueAccent,
//                       width: 2.5,
//                       markerSettings: const MarkerSettings(isVisible: true),
//                     ),
//                     ColumnSeries<RevenueDataPoint, String>(
//                       dataSource: revenueData,
//                       xValueMapper: (RevenueDataPoint data, _) =>
//                           DateFormat('E').format(data.date),
//                       yValueMapper: (RevenueDataPoint data, _) => data.orders,
//                       color: Colors.greenAccent.withOpacity(0.6),
//                       width: 0.4,
//                       borderRadius: BorderRadius.circular(4),
//                       yAxisName: 'secondary',
//                     ),
//                   ],
//                   tooltipBehavior: TooltipBehavior(
//                     enable: true,
//                     format: 'point.x : ${Constants.CURRENCY_NAME}point.y',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   double _calculateWeeklyGrowth(List<RevenueDataPoint> data) {
//     if (data.length < 2) return 0.0;
//
//     final firstHalf = data
//         .take(3)
//         .fold(0.0, (sum, point) => sum + point.revenue);
//     final secondHalf = data
//         .skip(3)
//         .fold(0.0, (sum, point) => sum + point.revenue);
//
//     if (firstHalf == 0) return secondHalf > 0 ? 100.0 : 0.0;
//     return ((secondHalf - firstHalf) / firstHalf * 100);
//   }
//
//   SliverToBoxAdapter _buildPerformanceMetrics() {
//     if (_dashboardData == null) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final stats = _dashboardData!.stats;
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Performance Metrics',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               GridView.count(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 12,
//                 mainAxisSpacing: 12,
//                 childAspectRatio: 2.5,
//                 children: [
//                   _MetricTile(
//                     label: 'Average Order Value',
//                     value: '${Constants.CURRENCY_NAME}${stats.averageOrderValue.toStringAsFixed(2)}',
//                     icon: Icons.receipt,
//                     color: Colors.blue,
//                   ),
//                   _MetricTile(
//                     label: 'Inventory Health',
//                     value: '${stats.lowStockProducts}/${stats.totalProducts} low',
//                     icon: Icons.inventory,
//                     color: stats.lowStockProducts > 5 ? Colors.orange : Colors.green,
//                   ),
//                   _MetricTile(
//                     label: 'Return Rate',
//                     value: stats.totalSales > 0
//                         ? '${(stats.totalReturns / stats.totalSales * 100).toStringAsFixed(1)}%'
//                         : '0%',
//                     icon: Icons.assignment_return,
//                     color: Colors.purple,
//                   ),
//                   _MetricTile(
//                     label: 'Customer Value',
//                     value: stats.totalCustomers > 0
//                         ? '${Constants.CURRENCY_NAME}${(stats.totalRevenue / stats.totalCustomers).toStringAsFixed(0)}'
//                         : '${Constants.CURRENCY_NAME}0',
//                     icon: Icons.person,
//                     color: Colors.teal,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   SliverToBoxAdapter _buildCategoryDistribution() {
//     if (_dashboardData == null || _dashboardData!.categoryDistribution.isEmpty) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final categories = _dashboardData!.categoryDistribution;
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Category Performance',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 height: 200,
//                 child: SfCircularChart(
//                   legend: Legend(
//                     isVisible: true,
//                     overflowMode: LegendItemOverflowMode.wrap,
//                     position: LegendPosition.bottom,
//                   ),
//                   series: <CircularSeries>[
//                     PieSeries<CategoryDistribution, String>(
//                       dataSource: categories,
//                       xValueMapper: (CategoryDistribution data, _) => data.categoryName,
//                       yValueMapper: (CategoryDistribution data, _) => data.revenue,
//                       dataLabelMapper: (CategoryDistribution data, _) =>
//                       '${data.categoryName}\n${Constants.CURRENCY_NAME}${data.revenue.toStringAsFixed(0)}',
//                       dataLabelSettings: const DataLabelSettings(
//                         isVisible: true,
//                         labelPosition: ChartDataLabelPosition.outside,
//                         textStyle: TextStyle(fontSize: 10),
//                       ),
//                       explode: true,
//                       explodeIndex: 0,
//                     ),
//                   ],
//                   tooltipBehavior: TooltipBehavior(
//                     enable: true,
//                     format: 'point.x : ${Constants.CURRENCY_NAME}point.y (point.percentage%)',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   SliverToBoxAdapter _buildHourlySalesChart() {
//     if (_dashboardData == null || _dashboardData!.hourlySales.isEmpty) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final hourlyData = _dashboardData!.hourlySales;
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Hourly Sales Pattern',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 height: 180,
//                 child: SfCartesianChart(
//                   margin: EdgeInsets.zero,
//                   plotAreaBorderWidth: 0,
//                   primaryXAxis: NumericAxis(
//                     minimum: 0,
//                     maximum: 23,
//                     interval: 4,
//                     majorGridLines: const MajorGridLines(width: 0),
//                     labelFormat: '{value}:00',
//                   ),
//                   primaryYAxis: NumericAxis(
//                     numberFormat: NumberFormat.compactCurrency(
//                       symbol: Constants.CURRENCY_NAME,
//                     ),
//                     majorGridLines: MajorGridLines(
//                       width: 1,
//                       color: Colors.grey[100],
//                     ),
//                   ),
//                   series: <CartesianSeries>[
//                     AreaSeries<HourlySalesData, int>(
//                       dataSource: hourlyData,
//                       xValueMapper: (HourlySalesData data, _) => data.hour,
//                       yValueMapper: (HourlySalesData data, _) => data.revenue,
//                       color: Colors.blue.withOpacity(0.3),
//                       borderColor: Colors.blue,
//                       borderWidth: 2,
//                       markerSettings: const MarkerSettings(isVisible: true),
//                     ),
//                   ],
//                   tooltipBehavior: TooltipBehavior(
//                     enable: true,
//                     format: 'Hour point.x:00\nRevenue: ${Constants.CURRENCY_NAME}point.y',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   SliverToBoxAdapter _buildPaymentMethodsSection() {
//     if (_dashboardData == null || _dashboardData!.paymentMethods.isEmpty) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final paymentMethods = _dashboardData!.paymentMethods;
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Payment Methods',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 height: 200,
//                 child: SfCartesianChart(
//                   margin: EdgeInsets.zero,
//                   plotAreaBorderWidth: 0,
//                   primaryXAxis: CategoryAxis(
//                     majorGridLines: const MajorGridLines(width: 0),
//                     labelStyle: const TextStyle(fontSize: 10),
//                   ),
//                   primaryYAxis: NumericAxis(
//                     numberFormat: NumberFormat.compactCurrency(
//                       symbol: Constants.CURRENCY_NAME,
//                     ),
//                     majorGridLines: MajorGridLines(
//                       width: 1,
//                       color: Colors.grey[100],
//                     ),
//                   ),
//                   series: <CartesianSeries>[
//                     BarSeries<PaymentMethodData, String>(
//                       dataSource: paymentMethods,
//                       xValueMapper: (PaymentMethodData data, _) => data.method,
//                       yValueMapper: (PaymentMethodData data, _) => data.amount,
//                       color: Colors.purple,
//                       width: 0.6,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                   ],
//                   tooltipBehavior: TooltipBehavior(
//                     enable: true,
//                     format: 'point.x\nAmount: ${Constants.CURRENCY_NAME}point.y\nTransactions: point.count',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   SliverToBoxAdapter _buildCustomerAnalytics() {
//     if (_dashboardData == null) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final analytics = _dashboardData!.customerAnalytics;
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Customer Analytics',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               GridView.count(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 12,
//                 mainAxisSpacing: 12,
//                 childAspectRatio: 2.5,
//                 children: [
//                   _MetricTile(
//                     label: 'New Customers',
//                     value: analytics.newCustomers.toString(),
//                     icon: Icons.person_add,
//                     color: Colors.green,
//                   ),
//                   _MetricTile(
//                     label: 'Returning Customers',
//                     value: analytics.returningCustomers.toString(),
//                     icon: Icons.repeat,
//                     color: Colors.blue,
//                   ),
//                   _MetricTile(
//                     label: 'Retention Rate',
//                     value: '${analytics.retentionRate.toStringAsFixed(1)}%',
//                     icon: Icons.loyalty,
//                     color: Colors.orange,
//                   ),
//                   _MetricTile(
//                     label: 'Avg Customer Value',
//                     value: '${Constants.CURRENCY_NAME}${analytics.averageCustomerValue.toStringAsFixed(0)}',
//                     icon: Icons.monetization_on,
//                     color: Colors.purple,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   SliverToBoxAdapter _buildDataStatusFooter() {
//     if (_dashboardData == null) {
//       return const SliverToBoxAdapter(child: SizedBox());
//     }
//
//     final lastUpdated = _dashboardData!.lastUpdated;
//     final isStale = _isDataStale(lastUpdated);
//     final formattedTime = DateFormat('MMM d, yyyy HH:mm').format(lastUpdated);
//
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: isStale ? Colors.amber[50] : Colors.green[50],
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//               color: isStale ? Colors.orange[200]! : Colors.green[200]!,
//               width: 1,
//             ),
//           ),
//           child: Row(
//             children: [
//               Icon(
//                 isStale ? Icons.warning_amber : Icons.check_circle,
//                 color: isStale ? Colors.orange : Colors.green,
//                 size: 16,
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   isStale
//                       ? 'Data may be stale. Last updated: $formattedTime'
//                       : 'Data is current. Last updated: $formattedTime',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: isStale ? Colors.orange[800] : Colors.green[800],
//                   ),
//                 ),
//               ),
//               if (isStale)
//                 TextButton(
//                   onPressed: _refreshData,
//                   style: TextButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(horizontal: 8),
//                     minimumSize: Size.zero,
//                   ),
//                   child: Text(
//                     'Refresh',
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.blue[700],
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   String _getGreeting() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return 'Morning';
//     if (hour < 17) return 'Afternoon';
//     return 'Evening';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: _hasError && _dashboardData == null
//           ? _buildErrorState()
//           : _isLoading && _dashboardData == null
//           ? _buildLoadingState()
//           : _buildDashboardContent(),
//     );
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       // Refresh data when app comes to foreground
//       if (_dashboardData != null && _isDataStale(_dashboardData!.lastUpdated)) {
//         _loadDashboardData();
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _autoRefreshTimer?.cancel();
//     _animationController.dispose();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
// }
//
// class _QuickActionButton extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color color;
//   final VoidCallback onPressed;
//
//   const _QuickActionButton({
//     required this.icon,
//     required this.label,
//     required this.color,
//     required this.onPressed,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return ElevatedButton.icon(
//       onPressed: onPressed,
//       icon: Icon(icon, size: 16),
//       label: Text(label),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         foregroundColor: Colors.white,
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//         ),
//       ),
//     );
//   }
// }
//
// class _StatCard extends StatelessWidget {
//   final String title;
//   final String value;
//   final String subtitle;
//   final IconData icon;
//   final Color color;
//   final double trend;
//
//   const _StatCard({
//     required this.title,
//     required this.value,
//     required this.subtitle,
//     required this.icon,
//     required this.color,
//     required this.trend,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(6),
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(icon, size: 20, color: color),
//               ),
//               const Spacer(),
//               if (trend != 0)
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: trend >= 0
//                         ? Colors.green.withOpacity(0.1)
//                         : Colors.red.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         trend >= 0 ? Icons.trending_up : Icons.trending_down,
//                         size: 12,
//                         color: trend >= 0 ? Colors.green : Colors.red,
//                       ),
//                       const SizedBox(width: 2),
//                       Text(
//                         '${trend.abs().toStringAsFixed(1)}%',
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w600,
//                           color: trend >= 0 ? Colors.green : Colors.red,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey[800],
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey[600],
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             subtitle,
//             style: TextStyle(
//               fontSize: 10,
//               color: Colors.grey[500],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _MetricTile extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;
//   final Color color;
//
//   const _MetricTile({
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.grey[50],
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[200]!),
//       ),
//       padding: const EdgeInsets.all(12),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(6),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Icon(icon, size: 16, color: color),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: TextStyle(
//                     fontSize: 11,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   value,
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.grey[800],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }