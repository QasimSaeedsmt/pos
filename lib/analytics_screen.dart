// analytics_screen.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'constants.dart';
import 'app.dart';

// Analytics Data Models
class SalesAnalytics {
  final double totalSales;
  final int totalOrders;
  final int totalItemsSold;
  final double averageOrderValue;
  final Map<String, double> salesByHour;
  final Map<String, double> salesByDay;
  final List<ProductPerformance> topProducts;
  final List<CategoryPerformance> topCategories;

  SalesAnalytics({
    required this.totalSales,
    required this.totalOrders,
    required this.totalItemsSold,
    required this.averageOrderValue,
    required this.salesByHour,
    required this.salesByDay,
    required this.topProducts,
    required this.topCategories,
  });
}

class ProductPerformance {
  final Product product;
  final int quantitySold;
  final double revenue;
  final double percentage;

  ProductPerformance({
    required this.product,
    required this.quantitySold,
    required this.revenue,
    required this.percentage,
  });
}

class CategoryPerformance {
  final Category category;
  final int quantitySold;
  final double revenue;
  final double percentage;

  CategoryPerformance({
    required this.category,
    required this.quantitySold,
    required this.revenue,
    required this.percentage,
  });
}

class TimePeriod {
  final String label;
  final DateTime startDate;
  final DateTime endDate;

  TimePeriod({
    required this.label,
    required this.startDate,
    required this.endDate,
  });
}

// Customer Analytics Data Models
class CustomerAnalytics {
  final int totalCustomers;
  final int newCustomers;
  final double? averageOrderValue;
  final double? repeatCustomerRate;
  final double customerGrowth;
  final List<CustomerSegment> customerSegmentation;
  final List<TopCustomer> topCustomers;
  final List<AcquisitionData> acquisitionData;
  final RetentionMetrics? retentionMetrics;
  final List<LocationData> locationData;

  CustomerAnalytics({
    required this.totalCustomers,
    required this.newCustomers,
    this.averageOrderValue,
    this.repeatCustomerRate,
    required this.customerGrowth,
    required this.customerSegmentation,
    required this.topCustomers,
    required this.acquisitionData,
    this.retentionMetrics,
    required this.locationData,
  });
}

class CustomerSegment {
  final String segment;
  final int count;
  final double percentage;

  CustomerSegment({
    required this.segment,
    required this.count,
    required this.percentage,
  });
}

class TopCustomer {
  final String customerId;
  final String customerName;
  final String email;
  final int totalOrders;
  final double totalSpent;
  final DateTime lastOrderDate;
  final String tier;

  TopCustomer({
    required this.customerId,
    required this.customerName,
    required this.email,
    required this.totalOrders,
    required this.totalSpent,
    required this.lastOrderDate,
    required this.tier,
  });
}

class AcquisitionData {
  final String period;
  final int newCustomers;
  final int returningCustomers;

  AcquisitionData({
    required this.period,
    required this.newCustomers,
    required this.returningCustomers,
  });
}

class RetentionMetrics {
  final double retention30Days;
  final double retention90Days;
  final double churnRate;
  final double averageLifetimeValue;

  RetentionMetrics({
    required this.retention30Days,
    required this.retention90Days,
    required this.churnRate,
    required this.averageLifetimeValue,
  });
}

class LocationData {
  final String city;
  final String state;
  final int customerCount;
  final double totalRevenue;

  LocationData({
    required this.city,
    required this.state,
    required this.customerCount,
    required this.totalRevenue,
  });
}

class ChartData {
  final String x;
  final double y;

  ChartData(this.x, this.y);
}

// Time Periods Utility
class TimePeriods {
  static final today = TimePeriod(
    label: 'Today',
    startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    endDate: DateTime.now(),
  );

  static final yesterday = TimePeriod(
    label: 'Yesterday',
    startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
    endDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1, 23, 59, 59),
  );

  static final thisWeek = TimePeriod(
    label: 'This Week',
    startDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
    endDate: DateTime.now(),
  );

  static final lastWeek = TimePeriod(
    label: 'Last Week',
    startDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday + 6)),
    endDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday)),
  );

  static final thisMonth = TimePeriod(
    label: 'This Month',
    startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
    endDate: DateTime.now(),
  );

  static final lastMonth = TimePeriod(
    label: 'Last Month',
    startDate: DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
    endDate: DateTime(DateTime.now().year, DateTime.now().month, 0),
  );

  static final allPeriods = [today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth];
}

// Analytics Service
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SalesAnalytics> getSalesAnalytics(TimePeriod period) async {
    try {
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
          .where('dateCreated', isLessThanOrEqualTo: period.endDate)
          .get();

      final orders = ordersSnapshot.docs.map((doc) {
        final data = doc.data();
        return Order.fromFirestore(data, doc.id);
      }).toList();

      final totalSales = orders.fold(0.0, (sum, order) => sum + order.total);
      final totalOrders = orders.length;
      final totalItemsSold = orders.fold(0, (sum, order) {
        return sum + (order.lineItems as List).fold(0, (itemSum, item) {
          final itemMap = item as Map<String, dynamic>;
          return itemSum + (itemMap['quantity'] as int);
        });
      });

      final averageOrderValue = totalOrders > 0 ? totalSales / totalOrders : 0.0;

      final salesByHour = <String, double>{};
      for (int hour = 0; hour < 24; hour++) {
        final hourSales = orders.where((order) {
          return order.dateCreated.hour == hour;
        }).fold(0.0, (sum, order) => sum + order.total);
        salesByHour['${hour.toString().padLeft(2, '0')}:00'] = hourSales;
      }

      final salesByDay = <String, double>{};
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (final day in days) {
        salesByDay[day] = 0.0;
      }

      for (final order in orders) {
        final dayName = DateFormat('E').format(order.dateCreated);
        salesByDay[dayName] = (salesByDay[dayName] ?? 0) + order.total;
      }

      final productSales = <String, Map<String, dynamic>>{};
      for (final order in orders) {
        for (final item in order.lineItems) {
          final itemMap = item as Map<String, dynamic>;
          final productId = itemMap['productId'].toString();
          final quantity = itemMap['quantity'] as int;
          final price = (itemMap['price'] as num).toDouble();

          if (!productSales.containsKey(productId)) {
            productSales[productId] = {
              'product': await _getProductById(productId),
              'quantity': 0,
              'revenue': 0.0,
            };
          }

          productSales[productId]!['quantity'] += quantity;
          productSales[productId]!['revenue'] += quantity * price;
        }
      }

      final topProducts = productSales.values
          .where((data) => data['product'] != null)
          .map((data) => ProductPerformance(
        product: data['product'] as Product,
        quantitySold: data['quantity'] as int,
        revenue: data['revenue'] as double,
        percentage: totalSales > 0 ? (data['revenue'] as double) / totalSales * 100 : 0,
      ))
          .toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      final topCategories = <CategoryPerformance>[];

      return SalesAnalytics(
        totalSales: totalSales,
        totalOrders: totalOrders,
        totalItemsSold: totalItemsSold,
        averageOrderValue: averageOrderValue,
        salesByHour: salesByHour,
        salesByDay: salesByDay,
        topProducts: topProducts.take(5).toList(),
        topCategories: topCategories,
      );
    } catch (e) {
      throw Exception('Failed to fetch analytics: $e');
    }
  }

  Future<CustomerAnalytics> getCustomerAnalytics(TimePeriod period) async {
    try {
      final customersSnapshot = await _firestore.collection('customers').get();
      final customers = customersSnapshot.docs.map((doc) {
        return Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
          .where('dateCreated', isLessThanOrEqualTo: period.endDate)
          .get();

      final totalCustomers = customers.length;
      final newCustomers = customers.where((c) {
        return c.dateCreated != null && c.dateCreated!.isAfter(period.startDate);
      }).length;

      final segmentation = _calculateCustomerSegmentation(customers);
      final topCustomers = await _getTopCustomers();
      final acquisitionData = await _getAcquisitionData(period);
      final retentionMetrics = await _calculateRetentionMetrics();
      final locationData = await _getLocationData(customers);

      return CustomerAnalytics(
        totalCustomers: totalCustomers,
        newCustomers: newCustomers,
        averageOrderValue: await _calculateAverageOrderValue(period),
        repeatCustomerRate: await _calculateRepeatCustomerRate(period),
        customerGrowth: await _calculateCustomerGrowth(period),
        customerSegmentation: segmentation,
        topCustomers: topCustomers,
        acquisitionData: acquisitionData,
        retentionMetrics: retentionMetrics,
        locationData: locationData,
      );
    } catch (e) {
      throw Exception('Failed to fetch customer analytics: $e');
    }
  }

  List<CustomerSegment> _calculateCustomerSegmentation(List<Customer> customers) {
    final total = customers.length;
    if (total == 0) return [];

    final vipCount = customers.where((c) => c.totalSpent > 1000).length;
    final regularCount = customers.where((c) => c.totalSpent > 100 && c.totalSpent <= 1000).length;
    final newCount = customers.where((c) => c.orderCount <= 1).length;
    final atRiskCount = customers.where((c) => c.dateModified != null && DateTime.now().difference(c.dateModified!).inDays > 90).length;
    final lostCount = customers.where((c) => c.dateModified != null && DateTime.now().difference(c.dateModified!).inDays > 180).length;

    return [
      CustomerSegment(segment: 'VIP', count: vipCount, percentage: (vipCount / total) * 100),
      CustomerSegment(segment: 'Regular', count: regularCount, percentage: (regularCount / total) * 100),
      CustomerSegment(segment: 'New', count: newCount, percentage: (newCount / total) * 100),
      CustomerSegment(segment: 'At Risk', count: atRiskCount, percentage: (atRiskCount / total) * 100),
      CustomerSegment(segment: 'Lost', count: lostCount, percentage: (lostCount / total) * 100),
    ];
  }

  Future<List<TopCustomer>> _getTopCustomers() async {
    try {
      final customersSnapshot = await _firestore
          .collection('customers')
          .orderBy('totalSpent', descending: true)
          .limit(10)
          .get();

      return customersSnapshot.docs.map((doc) {
        final data = doc.data();
        final customer = Customer.fromFirestore(data, doc.id);

        String tier = 'Bronze';
        if (customer.totalSpent > 1000) tier = 'Platinum';
        else if (customer.totalSpent > 500) tier = 'Gold';
        else if (customer.totalSpent > 100) tier = 'Silver';

        return TopCustomer(
          customerId: customer.id,
          customerName: customer.fullName,
          email: customer.email,
          totalOrders: customer.orderCount,
          totalSpent: customer.totalSpent,
          lastOrderDate: customer.dateModified ?? customer.dateCreated ?? DateTime.now(),
          tier: tier,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<AcquisitionData>> _getAcquisitionData(TimePeriod period) async {
    final weeks = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    return weeks.map((week) => AcquisitionData(
      period: week,
      newCustomers: Random().nextInt(20) + 5,
      returningCustomers: Random().nextInt(15) + 10,
    )).toList();
  }

  Future<RetentionMetrics?> _calculateRetentionMetrics() async {
    return RetentionMetrics(
      retention30Days: 65.5,
      retention90Days: 45.2,
      churnRate: 12.3,
      averageLifetimeValue: 180.0,
    );
  }

  Future<List<LocationData>> _getLocationData(List<Customer> customers) async {
    final locationMap = <String, LocationData>{};

    for (final customer in customers) {
      final city = customer.city ?? 'Unknown';
      final state = customer.state ?? 'Unknown';
      final key = '$city,$state';

      if (!locationMap.containsKey(key)) {
        locationMap[key] = LocationData(
          city: city,
          state: state,
          customerCount: 0,
          totalRevenue: 0,
        );
      }

      final location = locationMap[key]!;
      locationMap[key] = LocationData(
        city: city,
        state: state,
        customerCount: location.customerCount + 1,
        totalRevenue: location.totalRevenue + customer.totalSpent,
      );
    }

    return locationMap.values.toList()
      ..sort((a, b) => b.customerCount.compareTo(a.customerCount));
  }

  Future<double?> _calculateAverageOrderValue(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);
    return analytics.averageOrderValue;
  }

  Future<double?> _calculateRepeatCustomerRate(TimePeriod period) async {
    try {
      final customers = await _firestore.collection('customers').get();
      final totalCustomers = customers.size;
      final repeatCustomers = customers.docs.where((doc) {
        final data = doc.data();
        return (data['orderCount'] as num? ?? 0) > 1;
      }).length;

      return totalCustomers > 0 ? (repeatCustomers / totalCustomers) * 100 : 0;
    } catch (e) {
      return null;
    }
  }

  Future<double> _calculateCustomerGrowth(TimePeriod period) async {
    final previousPeriod = TimePeriod(
      label: 'Previous',
      startDate: period.startDate.subtract(Duration(days: period.endDate.difference(period.startDate).inDays)),
      endDate: period.startDate.subtract(Duration(days: 1)),
    );

    try {
      final currentCustomers = (await _firestore
          .collection('customers')
          .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
          .where('dateCreated', isLessThanOrEqualTo: period.endDate)
          .get()).size;

      final previousCustomers = (await _firestore
          .collection('customers')
          .where('dateCreated', isGreaterThanOrEqualTo: previousPeriod.startDate)
          .where('dateCreated', isLessThanOrEqualTo: previousPeriod.endDate)
          .get()).size;

      return previousCustomers > 0 ? ((currentCustomers - previousCustomers) / previousCustomers) * 100 : 0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<Product?> _getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Order>> getRecentOrders({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('orders')
        .orderBy('dateCreated', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      return Order.fromFirestore(doc.data(), doc.id);
    }).toList();
  }

  Future<Map<String, dynamic>> getCashSummary(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);
    return {
      'totalCash': analytics.totalSales,
      'cashOrders': analytics.totalOrders,
      'averageTransaction': analytics.averageOrderValue,
      'peakHour': _findPeakHour(analytics.salesByHour),
    };
  }

  String _findPeakHour(Map<String, double> salesByHour) {
    if (salesByHour.isEmpty) return 'N/A';
    var peakHour = salesByHour.entries.first;
    for (final entry in salesByHour.entries) {
      if (entry.value > peakHour.value) {
        peakHour = entry;
      }
    }
    return peakHour.key;
  }
}

// Analytics Dashboard Screen
class AnalyticsDashboardScreen extends StatefulWidget {
  @override
  _AnalyticsDashboardScreenState createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> with SingleTickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  TimePeriod _selectedPeriod = TimePeriods.today;
  SalesAnalytics? _analytics;
  List<Order> _recentOrders = [];
  Map<String, dynamic> _cashSummary = {};
  CustomerAnalytics? _customerAnalytics;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final results = await Future.wait([
        _analyticsService.getSalesAnalytics(_selectedPeriod),
        _analyticsService.getRecentOrders(),
        _analyticsService.getCashSummary(_selectedPeriod),
        _analyticsService.getCustomerAnalytics(_selectedPeriod),
      ]);

      setState(() {
        _analytics = results[0] as SalesAnalytics;
        _recentOrders = results[1] as List<Order>;
        _cashSummary = results[2] as Map<String, dynamic>;
        _customerAnalytics = results[3] as CustomerAnalytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(TimePeriod period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadAnalytics();
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: DropdownButton<TimePeriod>(
        value: _selectedPeriod,
        isExpanded: true,
        underline: SizedBox(),
        items: TimePeriods.allPeriods.map((period) {
          return DropdownMenuItem<TimePeriod>(
            value: period,
            child: Text(period.label, style: TextStyle(fontWeight: FontWeight.w500)),
          );
        }).toList(),
        onChanged: (period) => _onPeriodChanged(period!),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 16),
          Text('Loading Analytics...', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Failed to load analytics', style: TextStyle(fontSize: 18, color: Colors.grey[800])),
          SizedBox(height: 8),
          Text(_errorMessage, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // appBar: AppBar(
      //   backgroundColor: Colors.blue[700],
      //   elevation: 0,
      //   actions: [
      //     IconButton(
      //       icon: Icon(Icons.refresh),
      //       onPressed: _loadAnalytics,
      //       tooltip: 'Refresh',
      //     ),
      //   ],
      //   bottom: TabBar(
      //     controller: _tabController,
      //     labelColor: Colors.white,
      //     unselectedLabelColor: Colors.white70,
      //     indicatorColor: Colors.white,
      //     tabs: [
      //       Tab(text: 'Overview'),
      //       Tab(text: 'Sales'),
      //       Tab(text: 'Products'),
      //       Tab(text: 'Customers'),
      //     ],
      //   ),
      // ),
        body: Column(
          children: [
            // Tab Bar
            Container(
              color: Colors.blue.shade700,

              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Sales'),
                  Tab(text: 'Products'),
                  Tab(text: 'Customers'),
                ],
              ),
            ),

            // Period Selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPeriodSelector(),
            ),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _hasError
                  ? _buildErrorState()
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildSalesTab(),
                  _buildProductsTab(),
                  _buildCustomersTab(),
                ],
              ),
            ),
          ],
        ));

        }

  // Overview Tab
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildKeyMetrics(),
          SizedBox(height: 20),
          _buildRecentOrders(),
          SizedBox(height: 20),
          _buildCashSummary(),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          title: 'Total Sales',
          value: '${Constants.CURRENCY_NAME}${_analytics?.totalSales.toStringAsFixed(0) ?? '0'}',
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        _buildMetricCard(
          title: 'Total Orders',
          value: '${_analytics?.totalOrders ?? 0}',
          icon: Icons.shopping_cart,
          color: Colors.blue,
        ),
        _buildMetricCard(
          title: 'Items Sold',
          value: '${_analytics?.totalItemsSold ?? 0}',
          icon: Icons.inventory,
          color: Colors.orange,
        ),
        _buildMetricCard(
          title: 'Avg Order',
          value: '${Constants.CURRENCY_NAME}${_analytics?.averageOrderValue?.toStringAsFixed(0) ?? '0'}',
          icon: Icons.analytics,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue),
                SizedBox(width: 8),
                Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                Text('${_recentOrders.length} orders', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 16),
            ..._recentOrders.take(5).map((order) => _buildOrderListItem(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(Order order) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.receipt_long, color: Colors.green),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.number}', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(order.dateCreated),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSummary() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.money, color: Colors.green),
                SizedBox(width: 8),
                Text('Cash Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _buildCashMetric('Total Cash', '${Constants.CURRENCY_NAME}${_cashSummary['totalCash']?.toStringAsFixed(0) ?? '0'}'),
                _buildCashMetric('Transactions', '${_cashSummary['cashOrders'] ?? 0}'),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildCashMetric('Avg Transaction', '${Constants.CURRENCY_NAME}${_cashSummary['averageTransaction']?.toStringAsFixed(0) ?? '0'}'),
                _buildCashMetric('Peak Hour', _cashSummary['peakHour'] ?? 'N/A'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashMetric(String label, String value) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.all(4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // Sales Tab
  Widget _buildSalesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSalesTrendsChart(),
          SizedBox(height: 20),
          _buildHourlySalesChart(),
          SizedBox(height: 20),
          _buildDailySalesChart(),
        ],
      ),
    );
  }

  Widget _buildSalesTrendsChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: Center(
                child: Text(
                  'Sales trends chart would appear here\n(Requires more historical data)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlySalesChart() {
    final hourlyData = _analytics?.salesByHour.entries.map((entry) => ChartData(entry.key, entry.value)).toList() ?? [];
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales by Hour', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <ColumnSeries<ChartData, String>>[
                  ColumnSeries<ChartData, String>(
                    dataSource: hourlyData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    color: Colors.blue[400],
                    dataLabelSettings: DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.outer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySalesChart() {
    final dailyData = _analytics?.salesByDay.entries.map((entry) => ChartData(entry.key, entry.value)).toList() ?? [];
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales by Day', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <ColumnSeries<ChartData, String>>[
                  ColumnSeries<ChartData, String>(
                    dataSource: dailyData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    color: Colors.green[400],
                    dataLabelSettings: DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.outer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Products Tab
  Widget _buildProductsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTopProducts(),
          SizedBox(height: 20),
          _buildProductPerformance(),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text('Top Performing Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            ..._analytics?.topProducts.map((product) => _buildProductPerformanceItem(product)) ?? [
              Center(child: Text('No product data available', style: TextStyle(color: Colors.grey[600]))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductPerformanceItem(ProductPerformance performance) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              image: performance.product.imageUrl != null
                  ? DecorationImage(image: NetworkImage(performance.product.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: performance.product.imageUrl == null ? Icon(Icons.shopping_bag, color: Colors.grey[400]) : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(performance.product.name, style: TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Text(
                  '${performance.quantitySold} sold • ${Constants.CURRENCY_NAME}${performance.revenue.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
            child: Text(
              '${performance.percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPerformance() {
    final productData = _analytics?.topProducts.map((p) => ChartData(p.product.name, p.revenue)).toList() ?? [];
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Revenue Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 300,
              child: SfCircularChart(
                series: <PieSeries<ChartData, String>>[
                  PieSeries<ChartData, String>(
                    dataSource: productData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    dataLabelMapper: (ChartData data, _) => '${data.x}\n${Constants.CURRENCY_NAME}${data.y.toStringAsFixed(0)}',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Customers Tab
  Widget _buildCustomersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCustomerOverviewMetrics(),
          SizedBox(height: 20),
          _buildCustomerSegmentation(),
          SizedBox(height: 20),
          _buildTopCustomers(),
          SizedBox(height: 20),
          _buildCustomerAcquisitionRetention(),
          SizedBox(height: 20),
          _buildCustomerLocationAnalytics(),
        ],
      ),
    );
  }

  Widget _buildCustomerOverviewMetrics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple),
                SizedBox(width: 8),
                Text('Customer Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildCustomerMetricCard(
                  title: 'Total Customers',
                  value: '${_customerAnalytics?.totalCustomers ?? 0}',
                  subtitle: 'Active customers',
                  icon: Icons.people_outline,
                  color: Colors.purple,
                  trend: _customerAnalytics?.customerGrowth ?? 0,
                ),
                _buildCustomerMetricCard(
                  title: 'New Customers',
                  value: '${_customerAnalytics?.newCustomers ?? 0}',
                  subtitle: 'This period',
                  icon: Icons.person_add,
                  color: Colors.green,
                ),
                _buildCustomerMetricCard(
                  title: 'Avg Order Value',
                  value: '${Constants.CURRENCY_NAME}${_customerAnalytics?.averageOrderValue?.toStringAsFixed(0) ?? '0'}',
                  subtitle: 'Per customer',
                  icon: Icons.attach_money,
                  color: Colors.blue,
                ),
                _buildCustomerMetricCard(
                  title: 'Repeat Rate',
                  value: '${_customerAnalytics?.repeatCustomerRate?.toStringAsFixed(1) ?? '0'}%',
                  subtitle: 'Returning customers',
                  icon: Icons.repeat,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    double? trend,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (trend != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trend >= 0 ? Colors.green[50]! : Colors.red[50]!,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trend >= 0 ? Icons.trending_up : Icons.trending_down,
                          size: 14,
                          color: trend >= 0 ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: trend >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSegmentation() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text('Customer Segmentation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: _customerAnalytics?.customerSegmentation != null
                  ? SfCircularChart(
                series: <PieSeries<CustomerSegment, String>>[
                  PieSeries<CustomerSegment, String>(
                    dataSource: _customerAnalytics!.customerSegmentation,
                    xValueMapper: (CustomerSegment segment, _) => segment.segment,
                    yValueMapper: (CustomerSegment segment, _) => segment.count.toDouble(),
                    dataLabelMapper: (CustomerSegment segment, _) => '${segment.segment}\n${segment.count}',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                    explode: true,
                    explodeIndex: 0,
                  ),
                ],
              )
                  : Center(child: Text('No segmentation data available', style: TextStyle(color: Colors.grey[600]))),
            ),
            SizedBox(height: 16),
            if (_customerAnalytics?.customerSegmentation != null)
              ..._customerAnalytics!.customerSegmentation.map((segment) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: _getSegmentColor(segment.segment), shape: BoxShape.circle),
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text(segment.segment, style: TextStyle(fontWeight: FontWeight.w500))),
                      Text('${segment.count} customers', style: TextStyle(color: Colors.grey[600])),
                      SizedBox(width: 8),
                      Text(
                        '${segment.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomers() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text('Top Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                Text('By Lifetime Value', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 16),
            ..._customerAnalytics?.topCustomers.take(10).map((customer) => _buildTopCustomerItem(customer)) ?? [
              Center(child: Text('No customer data available', style: TextStyle(color: Colors.grey[600]))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomerItem(TopCustomer customer) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.person, color: Colors.purple, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.customerName, style: TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(customer.email, style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('${customer.totalOrders} orders', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    SizedBox(width: 12),
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Last: ${DateFormat('MMM dd').format(customer.lastOrderDate)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${Constants.CURRENCY_NAME}${customer.totalSpent.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getCustomerTierColor(customer.tier), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  customer.tier.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAcquisitionRetention() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.green),
                SizedBox(width: 8),
                Text('Customer Acquisition & Retention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            if (_customerAnalytics?.acquisitionData != null)
              Container(
                height: 250,
                child: SfCartesianChart(
                  primaryXAxis: CategoryAxis(),
                  primaryYAxis: NumericAxis(),
                  series: <ColumnSeries<AcquisitionData, String>>[
                    ColumnSeries<AcquisitionData, String>(
                      dataSource: _customerAnalytics!.acquisitionData,
                      xValueMapper: (AcquisitionData data, _) => data.period,
                      yValueMapper: (AcquisitionData data, _) => data.newCustomers.toDouble(),
                      name: 'New Customers',
                      color: Colors.green[400],
                    ),
                    ColumnSeries<AcquisitionData, String>(
                      dataSource: _customerAnalytics!.acquisitionData,
                      xValueMapper: (AcquisitionData data, _) => data.period,
                      yValueMapper: (AcquisitionData data, _) => data.returningCustomers.toDouble(),
                      name: 'Returning Customers',
                      color: Colors.blue[400],
                    ),
                  ],
                  legend: Legend(isVisible: true),
                ),
              )
            else
              Container(
                height: 200,
                child: Center(child: Text('No acquisition data available', style: TextStyle(color: Colors.grey[600]))),
              ),
            SizedBox(height: 16),
            if (_customerAnalytics?.retentionMetrics != null)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildRetentionMetric(
                    '30-Day Retention',
                    '${_customerAnalytics!.retentionMetrics!.retention30Days.toStringAsFixed(1)}%',
                    Colors.green,
                  ),
                  _buildRetentionMetric(
                    '90-Day Retention',
                    '${_customerAnalytics!.retentionMetrics!.retention90Days.toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                  _buildRetentionMetric(
                    'Churn Rate',
                    '${_customerAnalytics!.retentionMetrics!.churnRate.toStringAsFixed(1)}%',
                    Colors.red,
                  ),
                  _buildRetentionMetric(
                    'Avg Lifetime',
                    '${_customerAnalytics!.retentionMetrics!.averageLifetimeValue.toStringAsFixed(0)} days',
                    Colors.purple,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionMetric(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildCustomerLocationAnalytics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red),
                SizedBox(width: 8),
                Text('Customer Locations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            if (_customerAnalytics?.locationData != null && _customerAnalytics!.locationData.isNotEmpty)
              Column(
                children: _customerAnalytics!.locationData.take(5).map((location) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.location_city, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(child: Text(location.city, style: TextStyle(fontWeight: FontWeight.w500))),
                        Text('${location.customerCount} customers', style: TextStyle(color: Colors.grey[600])),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            '${Constants.CURRENCY_NAME}${location.totalRevenue.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              Container(
                height: 100,
                child: Center(child: Text('No location data available', style: TextStyle(color: Colors.grey[600]))),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSegmentColor(String segment) {
    switch (segment.toLowerCase()) {
      case 'vip':
        return Colors.amber;
      case 'regular':
        return Colors.blue;
      case 'new':
        return Colors.green;
      case 'at risk':
        return Colors.orange;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCustomerTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Colors.blue[800]!;
      case 'gold':
        return Colors.amber[700]!;
      case 'silver':
        return Colors.grey[600]!;
      case 'bronze':
        return Colors.orange[800]!;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}