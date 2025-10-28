// app.dart - Complete Flutter POS with Firestore & Product Management
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mpcm/printing/invoice_model.dart';
import 'package:mpcm/printing/invoice_service.dart';
import 'package:mpcm/printing/printing_setting_screen.dart';
import 'package:mpcm/sales/sales_management_screen.dart';
import 'package:mpcm/settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:synchronized/synchronized.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'analytics_screen.dart';
import 'constants.dart';
import 'features/product_selling/product_selling_base.dart';
import 'features/ticketing/ticketing.dart';
import 'features/users/users_base.dart';
import 'modules/auth/providers/auth_provider.dart';

// Modern Dashboard Screen with Real Data
class ModernDashboardScreen extends StatefulWidget {
  const ModernDashboardScreen({super.key});

  @override
  _ModernDashboardScreenState createState() => _ModernDashboardScreenState();
}
class _ModernDashboardScreenState extends State<ModernDashboardScreen>
    with SingleTickerProviderStateMixin {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final FirestoreService _firestore = FirestoreService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final LocalDatabase _localDb = LocalDatabase();

  // Real data variables
  DashboardStats _stats = DashboardStats.empty();
  List<Order> _recentOrders = [];
  List<Product> _lowStockProducts = [];
  List<RevenueDataPoint> _revenueData = [];
  List<TopSellingProduct> _topSellingProducts = [];
  List<Customer> _recentCustomers = [];

  bool _isLoading = true;
  bool _isOnline = true;
  bool _isRefreshing = false;
  bool _isOfflineMode = false;
  String _selectedPeriod = 'today';

  // Get auth provider from context
  MyAuthProvider get _authProvider {
    return Provider.of<MyAuthProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDashboardData();
    _setupConnectivityListener();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isRefreshing = true;
    });

    try {
      // Get auth provider from context to ensure we have the current user
      final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      final tenantId = currentUser.tenantId;
      if (tenantId.isEmpty || tenantId == 'super_admin') {
        throw Exception('Invalid tenant ID: $tenantId. User may be a super admin or not assigned to a tenant.');
      }

      print('Loading dashboard for tenant: $tenantId, user: ${currentUser.email}');

      // Check if we have recent cached data first
      final cachedData = await _localDb.getDashboardData(tenantId);
      if (cachedData != null && !_isRefreshing) {
        print('Loading dashboard from cache');
        _loadCachedData(cachedData);
        _isOfflineMode = false;
        return;
      }

      // Try to load online data
      try {
        await _loadOnlineData(tenantId);
        _isOfflineMode = false;
      } catch (onlineError) {
        print('Online data loading failed: $onlineError');

        // Fall back to offline data generation
        await _loadOfflineData(tenantId);
        _isOfflineMode = true;

        // Show offline mode warning
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Showing offline data. Some features may be limited.'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange[700],
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

    } catch (e) {
      print('Error loading dashboard data: $e');

      // Final fallback - try to generate data from local database
      try {
        final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
        final tenantId = authProvider.currentUser?.tenantId;
        if (tenantId != null) {
          await _loadOfflineData(tenantId);
          _isOfflineMode = true;
        } else {
          throw e;
        }
      } catch (fallbackError) {
        print('Fallback data loading also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isRefreshing = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadDashboardData,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  void _loadCachedData(OfflineDashboardData cachedData) {
    if (mounted) {
      setState(() {
        _stats = cachedData.stats;
        _recentOrders = cachedData.recentOrders;
        _lowStockProducts = cachedData.lowStockProducts;
        _revenueData = cachedData.revenueData;
        _topSellingProducts = cachedData.topSellingProducts;
        _recentCustomers = cachedData.recentCustomers;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadOnlineData(String tenantId) async {
    // Verify tenant exists and is active
    final tenantDoc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .get();

    if (!tenantDoc.exists) {
      throw Exception('Tenant not found in database. ID: $tenantId');
    }

    final tenantData = tenantDoc.data();
    if (tenantData != null && (tenantData['isActive'] == false)) {
      throw Exception('Tenant account is inactive. Please contact administrator.');
    }

    _firestore.setTenantId(tenantId);
    _posService.setTenantContext(tenantId);

    // Load all data with timeout protection
    final results = await Future.wait([
      _fetchDashboardStats(tenantId).timeout(Duration(seconds: 30)),
      _fetchRecentOrders(tenantId).timeout(Duration(seconds: 20)),
      _fetchLowStockProducts(tenantId).timeout(Duration(seconds: 20)),
      _fetchRevenueData(tenantId).timeout(Duration(seconds: 25)),
      _fetchTopSellingProducts(tenantId).timeout(Duration(seconds: 25)),
      _fetchRecentCustomers(tenantId).timeout(Duration(seconds: 20)),
    ], eagerError: true).catchError((error) {
      throw Exception('Data loading timeout: $error');
    });

    if (mounted) {
      setState(() {
        _stats = results[0] as DashboardStats;
        _recentOrders = results[1] as List<Order>;
        _lowStockProducts = results[2] as List<Product>;
        _revenueData = results[3] as List<RevenueDataPoint>;
        _topSellingProducts = results[4] as List<TopSellingProduct>;
        _recentCustomers = results[5] as List<Customer>;
        _isLoading = false;
        _isRefreshing = false;
      });
    }

    // Cache the data for offline use
    final offlineData = OfflineDashboardData(
      stats: _stats,
      recentOrders: _recentOrders,
      lowStockProducts: _lowStockProducts,
      revenueData: _revenueData,
      topSellingProducts: _topSellingProducts,
      recentCustomers: _recentCustomers,
      lastUpdated: DateTime.now(),
      tenantId: tenantId,
    );

    await _localDb.saveDashboardData(offlineData);
  }

  Future<void> _loadOfflineData(String tenantId) async {
    print('Loading dashboard data from offline sources');

    // Generate data from local database
    final results = await Future.wait([
      _localDb.generateOfflineStats(),
      _localDb.getPendingOrders().then((orders) => orders.take(5).map((order) {
        final orderData = order['order_data'] as Map<String, dynamic>;
        return Order.fromFirestore(orderData, order['id'].toString());
      }).toList()),
      _localDb.getLowStockProducts().then((products) => products.take(3).toList()),
      _localDb.generateRevenueData(),
      _localDb.generateTopSellingProducts(),
      _localDb.getRecentCustomers(limit: 5),
    ]);

    if (mounted) {
      setState(() {
        _stats = results[0] as DashboardStats;
        _recentOrders = results[1] as List<Order>;
        _lowStockProducts = results[2] as List<Product>;
        _revenueData = results[3] as List<RevenueDataPoint>;
        _topSellingProducts = results[4] as List<TopSellingProduct>;
        _recentCustomers = results[5] as List<Customer>;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }
  void _setupConnectivityListener() {
    _posService.onlineStatusStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);

        // If we come back online and were in offline mode, refresh data
        if (isOnline && _isOfflineMode) {
          _loadDashboardData();
        }
      }
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    await _loadDashboardData();
  }

  // Update your _buildStatusIndicator to show offline mode
  Widget _buildStatusIndicator() {
    return StreamBuilder<bool>(
      stream: _posService.onlineStatusStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        final isActuallyOnline = isOnline && !_isOfflineMode;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActuallyOnline ? Colors.green[400] : Colors.orange[400],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isActuallyOnline
                    ? Colors.green[400]!.withOpacity(0.3)
                    : Colors.orange[400]!.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                isActuallyOnline ? 'Live Data' : 'Offline Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isActuallyOnline) ...[
                SizedBox(width: 4),
                Icon(Icons.wifi_off, size: 12, color: Colors.white),
              ],
            ],
          ),
        );
      },
    );
  }

  // Update your _buildLoadingState to show offline status
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                _isOfflineMode ? Colors.orange[700]! : Colors.blue[700]!,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            _isOfflineMode
                ? 'Loading Offline Dashboard Data...'
                : 'Loading Dashboard Data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _isOfflineMode
                ? 'Using locally stored data'
                : 'Fetching from your database',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          if (_isOfflineMode) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Future<DashboardStats> _fetchDashboardStats(String tenantId) async {
    _firestore.setTenantId(tenantId);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final yesterdayStart = todayStart.subtract(Duration(days: 1));
    final yesterdayEnd = todayEnd.subtract(Duration(days: 1));

    try {
      // Fetch all required data with validation
      final futures = await Future.wait([
        _firestore.ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
            .get(),
        _firestore.ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(yesterdayEnd))
            .get(),
        _firestore.ordersRef.get(),
        _firestore.productsRef.where('status', isEqualTo: 'publish').get(),
        _firestore.customersRef.get(),
        _firestore.returnsRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .get(),
        _firestore.returnsRef.get(),
      ]);

      // Validate we got all data
      for (var i = 0; i < futures.length; i++) {

      }

      final todayOrdersSnapshot = futures[0];
      final yesterdayOrdersSnapshot = futures[1];
      final allOrdersSnapshot = futures[2];
      final productsSnapshot = futures[3];
      final customersSnapshot = futures[4];
      final todayReturnsSnapshot = futures[5];
      final allReturnsSnapshot = futures[6];

      // Calculate real metrics
      final todayOrders = todayOrdersSnapshot.docs;
      final yesterdayOrders = yesterdayOrdersSnapshot.docs;
      final allOrders = allOrdersSnapshot.docs;
      final allProducts = productsSnapshot.docs;
      final allCustomers = customersSnapshot.docs;
      final todayReturns = todayReturnsSnapshot.docs;
      final totalReturns = allReturnsSnapshot.docs;

      // Calculate today's revenue
      double todayRevenue = 0.0;
      for (final order in todayOrders) {
        final data = order.data() as Map<String, dynamic>;
        final total = (data['total'] as num?)?.toDouble() ??
            (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        todayRevenue += total;
      }

      // Calculate yesterday's revenue
      double yesterdayRevenue = 0.0;
      for (final order in yesterdayOrders) {
        final data = order.data() as Map<String, dynamic>;
        final total = (data['total'] as num?)?.toDouble() ??
            (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        yesterdayRevenue += total;
      }

      // Calculate total revenue
      double totalRevenue = 0.0;
      for (final order in allOrders) {
        final data = order.data() as Map<String, dynamic>;
        final total = (data['total'] as num?)?.toDouble() ??
            (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += total;
      }

      // Calculate low stock products
      int lowStockCount = 0;
      for (final product in allProducts) {
        final data = product.data() as Map<String, dynamic>;
        final stockQuantity = (data['stockQuantity'] as num?)?.toInt() ??
            (data['stock'] as num?)?.toInt() ?? 0;
        if (stockQuantity <= 10) {
          lowStockCount++;
        }
      }

      // Today's unique customers
      final todayCustomerIds = <String>{};
      for (final order in todayOrders) {
        final data = order.data() as Map<String, dynamic>;
        final customerId = data['customerId']?.toString();
        if (customerId != null && customerId.isNotEmpty && customerId != 'null') {
          todayCustomerIds.add(customerId);
        }
      }

      // Calculate derived metrics
      final averageOrderValue = allOrders.isNotEmpty
          ? totalRevenue / allOrders.length
          : 0.0;
      final conversionRate = allCustomers.isNotEmpty
          ? (allOrders.length / allCustomers.length * 100).clamp(0.0, 100.0)
          : 0.0;

      final revenueGrowth = _calculateGrowthPercentage(todayRevenue, yesterdayRevenue);
      final salesGrowth = _calculateGrowthPercentage(todayOrders.length.toDouble(), yesterdayOrders.length.toDouble());

      return DashboardStats(
        totalRevenue: totalRevenue,
        todayRevenue: todayRevenue,
        totalSales: allOrders.length,
        todaySales: todayOrders.length,
        totalProducts: allProducts.length,
        lowStockProducts: lowStockCount,
        totalCustomers: allCustomers.length,
        todayCustomers: todayCustomerIds.length,
        averageOrderValue: averageOrderValue,
        conversionRate: conversionRate,
        revenueGrowth: revenueGrowth,
        salesGrowth: salesGrowth,
        todayReturns: todayReturns.length,
        totalReturns: totalReturns.length,
      );
    } catch (e) {
      print('Error in _fetchDashboardStats: $e');
      return DashboardStats.empty();
    }
  }

  double _calculateGrowthPercentage(double today, double yesterday) {
    if (yesterday == 0) return today > 0 ? 100.0 : 0.0;
    return ((today - yesterday) / yesterday * 100);
  }

  Future<List<Order>> _fetchRecentOrders(String tenantId) async {
    try {
      _firestore.setTenantId(tenantId);

      final ordersSnapshot = await _firestore.ordersRef
          .orderBy('dateCreated', descending: true)
          .limit(5)
          .get();

      return ordersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Order.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error fetching recent orders: $e');
      return [];
    }
  }

  Future<List<Product>> _fetchLowStockProducts(String tenantId) async {
    try {
      _firestore.setTenantId(tenantId);

      final productsSnapshot = await _firestore.productsRef
          .where('status', isEqualTo: 'publish')
          .where('stockQuantity', isLessThanOrEqualTo: 10)
          .orderBy('stockQuantity')
          .limit(3)
          .get();

      return productsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error fetching low stock products: $e');
      return [];
    }
  }

  Future<List<RevenueDataPoint>> _fetchRevenueData(String tenantId) async {
    _firestore.setTenantId(tenantId);

    final now = DateTime.now();
    final List<RevenueDataPoint> revenueData = [];

    try {
      for (int i = 6; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day - i);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        final ordersSnapshot = await _firestore.ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();

        double dayRevenue = 0.0;
        int dayOrders = 0;

        for (final order in ordersSnapshot.docs) {
          final data = order.data() as Map<String, dynamic>;
          final total = (data['total'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          dayRevenue += total;
          dayOrders++;
        }

        revenueData.add(
          RevenueDataPoint(date: date, revenue: dayRevenue, orders: dayOrders),
        );
      }

      return revenueData;
    } catch (e) {
      print('Error generating revenue data: $e');
      return [];
    }
  }

  Future<List<TopSellingProduct>> _fetchTopSellingProducts(String tenantId) async {
    _firestore.setTenantId(tenantId);

    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final ordersSnapshot = await _firestore.ordersRef
          .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final productSales = <String, TopSellingProduct>{};

      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final lineItems = orderData['lineItems'] as List<dynamic>? ?? [];

        for (final item in lineItems) {
          final itemMap = item as Map<String, dynamic>;
          final productId = itemMap['productId']?.toString() ?? '';
          final productName = itemMap['productName']?.toString() ?? 'Unknown Product';
          final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
          final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

          if (productId.isNotEmpty) {
            if (productSales.containsKey(productId)) {
              final existing = productSales[productId]!;
              productSales[productId] = TopSellingProduct(
                productId: productId,
                productName: productName,
                totalSold: existing.totalSold + quantity,
                totalRevenue: existing.totalRevenue + (price * quantity),
                imageUrl: existing.imageUrl,
              );
            } else {
              String? imageUrl;
              try {
                final productDoc = await _firestore.productsRef.doc(productId).get();
                if (productDoc.exists) {
                  final productData = productDoc.data() as Map<String, dynamic>?;
                  imageUrl = productData?['imageUrl']?.toString();
                }
              } catch (e) {
                print('Error fetching product image: $e');
              }

              productSales[productId] = TopSellingProduct(
                productId: productId,
                productName: productName,
                totalSold: quantity,
                totalRevenue: price * quantity,
                imageUrl: imageUrl,
              );
            }
          }
        }
      }

      final sortedList = productSales.values.toList();
      sortedList.sort((a, b) => b.totalSold.compareTo(a.totalSold));
      return sortedList.take(5).toList();
    } catch (e) {
      print('Error fetching top selling products: $e');
      return [];
    }
  }

  Future<List<Customer>> _fetchRecentCustomers(String tenantId) async {
    try {
      _posService.setTenantContext(tenantId);
      final customers = await _posService.getAllCustomers();
      return customers.take(5).toList();
    } catch (e) {
      print('Error fetching recent customers: $e');
      return [];
    }
  }


  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Time Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildPeriodOption('Today', 'today'),
            _buildPeriodOption('This Week', 'week'),
            _buildPeriodOption('This Month', 'month'),
            _buildPeriodOption('This Year', 'year'),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodOption(String label, String value) {
    return ListTile(
      leading: Icon(Icons.calendar_today, color: Colors.blue),
      title: Text(label),
      trailing: _selectedPeriod == value
          ? Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        setState(() => _selectedPeriod = value);
        Navigator.pop(context);
        _loadDashboardData();
      },
    );
  }

  // Navigation methods
  void _navigateToSales() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductSellingScreen(cartManager: EnhancedCartManager()),
      ),
    );
  }

  void _navigateToInventory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductManagementScreen()),
    );
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AnalyticsDashboardScreen()),
    );
  }

  void _navigateToCustomers() {
    // Navigate to customers screen
    // Navigator.push(context, MaterialPageRoute(builder: (context) => CustomersScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading ? _buildLoadingState() : _buildDashboard(),
    );
  }



  Widget _buildDashboard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  _buildHeader(),
                  _buildStatsGrid(),
                  _buildMainContent(),
                  _buildActivitySection(),
                  SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _validateTenantAccess() async {
    final user = _authProvider.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final tenantId = user.tenantId;
    if (tenantId.isEmpty) {
      throw Exception('User ${user.uid} has no tenant ID assigned');
    }

    final tenantDoc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .get();

    if (!tenantDoc.exists) {
      throw Exception('Tenant $tenantId does not exist in database');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      throw Exception('User ${user.uid} not found in tenant $tenantId');
    }

    print('Tenant validation successful: $tenantId');
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dashboard Error'),
        content: Text('Failed to load dashboard data: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadDashboardData();
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }





  SliverToBoxAdapter _buildHeader() {
    final user = _authProvider.currentUser;
    final tenantId = user?.tenantId ?? 'No Tenant ID';

    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[700]!, Colors.blue[800]!, Colors.indigo[900]!],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, 60, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_getGreeting()},',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _authProvider.currentTenant?.businessName ??
                            'Your Business (Tenant: ${tenantId.substring(0, min(8, tenantId.length))}...)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Real-time Business Overview',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (kDebugMode) ...[
                        SizedBox(height: 4),
                        Text(
                          'User: ${user?.uid.substring(0, 8)}... | Tenant: $tenantId',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    _buildStatusIndicator(),
                    SizedBox(height: 8),
                    if (_isRefreshing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.white70),
                        onPressed: _refreshData,
                        tooltip: 'Refresh Data',
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildQuickStatsBar(),
          ],
        ),
      ),
    );
  }



  Widget _buildQuickStatsBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickStatItem(
            value: _stats.todaySales.toString(),
            label: 'Today Sales',
            icon: Icons.shopping_cart,
          ),
          _QuickStatItem(
            value: '${Constants.CURRENCY_NAME}${_stats.todayRevenue.toStringAsFixed(0)}',
            label: "Today's Revenue",
            icon: Icons.attach_money,
          ),
          _QuickStatItem(
            value: _stats.todayCustomers.toString(),
            label: 'Today Customers',
            icon: Icons.people,
          ),
          _QuickStatItem(
            value: _stats.todayReturns.toString(),
            label: 'Today Returns',
            icon: Icons.assignment_return,
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildStatsGrid() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _StatCard(
              title: 'Total Revenue',
              value: '${Constants.CURRENCY_NAME}${_stats.totalRevenue.toStringAsFixed(0)}',
              subtitle: '${Constants.CURRENCY_NAME}${_stats.todayRevenue.toStringAsFixed(0)} today',
              icon: Icons.attach_money,
              color: Colors.green,
              trend: _stats.revenueGrowth,
            ),
            _StatCard(
              title: 'Total Sales',
              value: _stats.totalSales.toString(),
              subtitle: '${_stats.todaySales} today',
              icon: Icons.shopping_cart,
              color: Colors.blue,
              trend: _stats.salesGrowth,
            ),
            _StatCard(
              title: 'Average Order',
              value: '${Constants.CURRENCY_NAME}${_stats.averageOrderValue.toStringAsFixed(0)}',
              subtitle: 'Per transaction',
              icon: Icons.trending_up,
              color: Colors.purple,
              trend: 0.0,
            ),
            _StatCard(
              title: 'Conversion Rate',
              value: '${_stats.conversionRate.toStringAsFixed(1)}%',
              subtitle: 'Customer conversion',
              icon: Icons.people,
              color: Colors.orange,
              trend: 0.0,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildMainContent() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _buildRevenueChart(),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildQuickActions()),
                SizedBox(width: 16),
                Expanded(child: _buildLowStockAlert()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final weeklyGrowth = _calculateWeeklyGrowth();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Revenue Overview (Last 7 Days)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: weeklyGrowth >= 0 ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${weeklyGrowth >= 0 ? '+' : ''}${weeklyGrowth.toStringAsFixed(1)}% this week',
                  style: TextStyle(
                    color: weeklyGrowth >= 0
                        ? Colors.green[700]
                        : Colors.red[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: MajorGridLines(width: 0),
                labelStyle: TextStyle(fontSize: 12),
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.compactCurrency(
                  symbol: Constants.CURRENCY_NAME,
                ),
                majorGridLines: MajorGridLines(
                  width: 1,
                  color: Colors.grey[100],
                ),
                labelStyle: TextStyle(fontSize: 12),
              ),
              series: <CartesianSeries>[
                ColumnSeries<RevenueDataPoint, String>(
                  dataSource: _revenueData,
                  xValueMapper: (RevenueDataPoint data, _) =>
                      DateFormat('E').format(data.date),
                  yValueMapper: (RevenueDataPoint data, _) => data.revenue,
                  color: Colors.blue[400],
                  width: 0.6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateWeeklyGrowth() {
    if (_revenueData.length < 2) return 0.0;

    final firstHalf = _revenueData
        .take(3)
        .fold(0.0, (sum, data) => sum + data.revenue);
    final secondHalf = _revenueData
        .skip(3)
        .fold(0.0, (sum, data) => sum + data.revenue);

    if (firstHalf == 0) return secondHalf > 0 ? 100.0 : 0.0;
    return ((secondHalf - firstHalf) / firstHalf * 100);
  }

  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Column(
            children: [
              _QuickActionTile(
                icon: Icons.point_of_sale,
                title: 'New Sale',
                subtitle: 'Start a new transaction',
                color: Colors.blue,
                onTap: _navigateToSales,
              ),
              _QuickActionTile(
                icon: Icons.inventory_2,
                title: 'Manage Inventory',
                subtitle: 'View and update stock',
                color: Colors.green,
                onTap: _navigateToInventory,
              ),
              _QuickActionTile(
                icon: Icons.analytics,
                title: 'View Analytics',
                subtitle: 'Detailed business insights',
                color: Colors.purple,
                onTap: _navigateToAnalytics,
              ),
              _QuickActionTile(
                icon: Icons.people,
                title: 'Customers',
                subtitle: 'Manage customer database',
                color: Colors.orange,
                onTap: _navigateToCustomers,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Low Stock Alert',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              if (_lowStockProducts.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_lowStockProducts.length} items',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          _lowStockProducts.isEmpty
              ? _buildNoLowStock()
              : Column(
            children: _lowStockProducts
                .map((product) => _LowStockItem(product: product))
                .toList(),
          ),
          if (_lowStockProducts.isNotEmpty) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _navigateToInventory,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  padding: EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  'View All Low Stock',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoLowStock() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.green[300]),
          SizedBox(height: 8),
          Text(
            'All products are well stocked',
            style: TextStyle(
              color: Colors.green[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildActivitySection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildRecentOrders(),
                  SizedBox(height: 16),
                  _buildTopProducts(),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(flex: 1, child: _buildRecentCustomers()),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              Text(
                '${_recentOrders.length} orders',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          _recentOrders.isEmpty
              ? _buildNoRecentActivity()
              : Column(
            children: _recentOrders
                .map((order) => _RecentOrderItem(order: order))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Selling Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _topSellingProducts.isEmpty
              ? _buildNoTopProducts()
              : Column(
            children: _topSellingProducts
                .map((product) => _TopProductItem(product: product))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCustomers() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Customers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _recentCustomers.isEmpty
              ? _buildNoRecentCustomers()
              : Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _recentCustomers.length,
              itemBuilder: (context, index) {
                final customer = _recentCustomers[index];
                return _RecentCustomerItem(customer: customer);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecentActivity() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text(
            'No recent transactions',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTopProducts() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.star_outline, size: 48, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text(
            'No sales data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecentCustomers() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text('No customers', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class DashboardStats {
  final double totalRevenue;
  final double todayRevenue;
  final int totalSales;
  final int todaySales;
  final int totalProducts;
  final int lowStockProducts;
  final int totalCustomers;
  final int todayCustomers;
  final double averageOrderValue;
  final double conversionRate;
  final double revenueGrowth;
  final double salesGrowth;
  final int todayReturns;
  final int totalReturns;

  const DashboardStats({
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
    );
  }
}

class RevenueDataPoint {
  final DateTime date;
  final double revenue;
  final int orders;

  RevenueDataPoint({
    required this.date,
    required this.revenue,
    required this.orders,
  });
}

class TopSellingProduct {
  final String productId;
  final String productName;
  final int totalSold;
  final double totalRevenue;
  final String? imageUrl;

  TopSellingProduct({
    required this.productId,
    required this.productName,
    required this.totalSold,
    required this.totalRevenue,
    this.imageUrl,
  });
}


// Supporting Widgets
class _QuickStatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _QuickStatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double trend;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend >= 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        trend >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: trend >= 0 ? Colors.green[600] : Colors.red[600],
                      ),
                      SizedBox(width: 2),
                      Text(
                        '${trend.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: trend >= 0
                              ? Colors.green[600]
                              : Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final Product product;

  const _LowStockItem({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              image: product.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: product.imageUrl == null
                ? Center(
                    child: Icon(
                      Icons.inventory_2,
                      size: 20,
                      color: Colors.orange,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Only ${product.stockQuantity} left',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18, color: Colors.orange[700]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RestockProductScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentOrderItem extends StatelessWidget {
  final Order order;

  const _RecentOrderItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt, size: 20, color: Colors.green[600]),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.number}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${order.lineItems.length} items • ${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(order.dateCreated),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _TopProductItem extends StatelessWidget {
  final TopSellingProduct product;

  const _TopProductItem({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              image: product.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: product.imageUrl == null
                ? Center(
                    child: Icon(
                      Icons.shopping_bag,
                      size: 20,
                      color: Colors.grey,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${product.totalSold} sold • ${Constants.CURRENCY_NAME}${product.totalRevenue.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCustomerItem extends StatelessWidget {
  final Customer customer;

  const _RecentCustomerItem({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.person, size: 20, color: Colors.blue),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.fullName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  customer.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final tenant = authProvider.currentTenant;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.business, size: 40),
                  ),
                  SizedBox(height: 16),
                  Text(
                    tenant!.businessName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Subscription: ${tenant.subscriptionPlan}'),
                  Text(
                    'Expires: ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry)}',
                  ),
                  SizedBox(height: 16),
                  tenant.isSubscriptionActive
                      ? Chip(
                          label: Text(
                            'Active',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        )
                      : Chip(
                          label: Text(
                            'Expired',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                        ),
                ],
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () {
              final authProvider = Provider.of<MyAuthProvider>(
                context,
                listen: false,
              );
              authProvider.logout();
            },
            child: Text("Logout"),
          ),
          SizedBox(height: 20),

          // Expanded(
          //   child: ListView(
          //     children: [
          //       ListTile(
          //         leading: Icon(Icons.support),
          //         title: Text('Support Tickets'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => TicketsScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.settings),
          //         title: Text('Branding & Settings'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => BrandingScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.analytics),
          //         title: Text('Analytics & Reports'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => AnalyticsScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.notifications),
          //         title: Text('Notifications'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => NotificationsScreen()),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}


class ProductSearchDialog extends StatefulWidget {
  final EnhancedPOSService posService;

  const ProductSearchDialog({super.key, required this.posService});

  @override
  _ProductSearchDialogState createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<Product> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Load some initial products
    _loadInitialProducts();
  }

  void _loadInitialProducts() async {
    setState(() => _isSearching = true);
    try {
      final products = await widget.posService.fetchProducts(limit: 20);
      setState(() {
        _searchResults.clear();
        _searchResults.addAll(products);
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _searchProducts(String query) {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _loadInitialProducts();
      return;
    }

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await widget.posService.searchProducts(query);
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(results);
          _isSearching = false;
        });
      } catch (e) {
        setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(20),
      child: Container(
        padding: EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Text(
              'Search Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by product name or SKU...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadInitialProducts();
                        },
                      )
                    : null,
              ),
              onChanged: _searchProducts,
              autofocus: true,
            ),
            SizedBox(height: 16),
            if (_isSearching)
              Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_searchResults.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Search for products to return'
                            : 'No products found for "${_searchController.text}"',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            image: product.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(product.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: product.imageUrl == null
                              ? Icon(Icons.shopping_bag, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          product.name,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.sku.isNotEmpty)
                              Text('SKU: ${product.sku}'),
                            Text(
                              '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(2)} • Stock: ${product.stockQuantity}',
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward, color: Colors.blue),
                        onTap: () => Navigator.pop(context, product),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

// Add these to your data models section
class Customer {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final int orderCount;
  final double totalSpent;
  final String? notes;
  final Map<String, dynamic> metaData;

  Customer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postcode,
    this.country,
    this.dateCreated,
    this.dateModified,
    this.orderCount = 0,
    this.totalSpent = 0.0,
    this.notes,
    this.metaData = const {},
  });

  String get fullName => '$firstName $lastName';
  String get displayName =>
      company?.isNotEmpty == true ? '$fullName ($company)' : fullName;

  factory Customer.fromFirestore(Map<String, dynamic> data, String id) {
    return Customer(
      id: id,
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      company: data['company']?.toString(),
      address1: data['address1']?.toString(),
      address2: data['address2']?.toString(),
      city: data['city']?.toString(),
      state: data['state']?.toString(),
      postcode: data['postcode']?.toString(),
      country: data['country']?.toString(),
      dateCreated: data['dateCreated'] is Timestamp
          ? (data['dateCreated'] as Timestamp).toDate()
          : null,
      dateModified: data['dateModified'] is Timestamp
          ? (data['dateModified'] as Timestamp).toDate()
          : null,
      orderCount: data['orderCount'] ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes']?.toString(),
      metaData: data['metaData'] is Map
          ? Map<String, dynamic>.from(data['metaData'])
          : {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'company': company,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
      'dateCreated': dateCreated?.toIso8601String(),
      'dateModified': dateModified?.toIso8601String(),
      'orderCount': orderCount,
      'totalSpent': totalSpent,
      'notes': notes,
      'metaData': metaData,
      'searchKeywords': _generateSearchKeywords(),
    };
  }

  List<String> _generateSearchKeywords() {
    final keywords = <String>[];
    keywords.addAll(fullName.toLowerCase().split(' '));
    keywords.addAll(email.toLowerCase().split('@'));
    keywords.add(phone);
    if (company != null) {
      keywords.addAll(company!.toLowerCase().split(' '));
    }
    return keywords.where((k) => k.length > 1).toSet().toList();
  }

  Customer copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postcode,
    String? country,
    String? notes,
  }) {
    return Customer(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      postcode: postcode ?? this.postcode,
      country: country ?? this.country,
      dateCreated: dateCreated,
      dateModified: DateTime.now(),
      orderCount: orderCount,
      totalSpent: totalSpent,
      notes: notes ?? this.notes,
      metaData: metaData,
    );
  }
}

class CustomerSelection {
  final Customer? customer;
  final bool createNew;
  final bool useDefault;

  CustomerSelection({
    this.customer,
    this.createNew = false,
    this.useDefault = false,
  });

  bool get hasCustomer => customer != null && !useDefault;
}

// Enhanced ReturnReason model
class ReturnReason {
  final String id;
  final String name;
  final String description;
  final bool requiresApproval;

  ReturnReason({
    required this.id,
    required this.name,
    required this.description,
    this.requiresApproval = false,
  });

  @override
  String toString() => name;
}

// Enhanced ReturnItem model
class ReturnItem {
  final String productId;
  final String productName;
  final String productSku;
  final int quantity;
  final double price;
  final String returnReason;
  final String? notes;

  ReturnItem({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.price,
    required this.returnReason,
    this.notes,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productSku': productSku,
      'quantity': quantity,
      'price': price,
      'returnReason': returnReason,
      'notes': notes,
      'subtotal': subtotal,
    };
  }

  // In ReturnItem class - ENHANCE the fromMap method:

  factory ReturnItem.fromMap(Map<String, dynamic> map) {
    return ReturnItem(
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      productSku: map['productSku']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      returnReason: map['returnReason']?.toString() ?? '',
      notes: map['notes']?.toString(),
    );
  }
}

// Enhanced Return models with offline support
class ReturnRequest {
  final String id;
  final String orderId;
  final String orderNumber;
  final List<ReturnItem> items;
  final String reason;
  final String status; // pending, approved, rejected, completed, refunded
  final String? notes;
  final DateTime dateCreated;
  final DateTime? dateUpdated;
  final double refundAmount;
  final String refundMethod; // original, cash, credit, store_credit
  final String? customerId;
  final Map<String, dynamic>? customerInfo;
  final String? processedBy;
  final bool isOffline;
  final String? offlineId;
  final String syncStatus; // pending, synced, failed

  ReturnRequest({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.items,
    required this.reason,
    required this.status,
    this.notes,
    required this.dateCreated,
    this.dateUpdated,
    required this.refundAmount,
    required this.refundMethod,
    this.customerId,
    this.customerInfo,
    this.processedBy,
    this.isOffline = false,
    this.offlineId,
    this.syncStatus = 'synced',
  });

  bool get isCompleted => status == 'completed' || status == 'refunded';
  bool get canRefund => status == 'approved' || status == 'completed';
  bool get needsSync => isOffline && syncStatus == 'pending';

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'reason': reason,
      'status': status,
      'notes': notes,
      'dateCreated': Timestamp.fromDate(dateCreated),
      'dateUpdated': dateUpdated != null
          ? Timestamp.fromDate(dateUpdated!)
          : FieldValue.serverTimestamp(),
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'customerId': customerId,
      'customerInfo': customerInfo,
      'processedBy': processedBy,
      'isOffline': isOffline,
      'offlineId': offlineId,
      'syncStatus': syncStatus,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'reason': reason,
      'status': status,
      'notes': notes,
      'dateCreated': dateCreated.toIso8601String(),
      'dateUpdated': dateUpdated?.toIso8601String(),
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'customerId': customerId,
      'customerInfo': customerInfo,
      'processedBy': processedBy,
      'isOffline': isOffline,
      'offlineId': offlineId,
      'syncStatus': syncStatus,
    };
  }

  factory ReturnRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return ReturnRequest(
      id: id,
      orderId: data['orderId'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => ReturnItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      dateCreated: (data['dateCreated'] as Timestamp).toDate(),
      dateUpdated: data['dateUpdated'] != null
          ? (data['dateUpdated'] as Timestamp).toDate()
          : null,
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
      refundMethod: data['refundMethod'] ?? 'original',
      customerId: data['customerId'],
      customerInfo: data['customerInfo'] != null
          ? Map<String, dynamic>.from(data['customerInfo'])
          : null,
      processedBy: data['processedBy'],
      isOffline: data['isOffline'] ?? false,
      offlineId: data['offlineId'],
      syncStatus: data['syncStatus'] ?? 'synced',
    );
  }

  factory ReturnRequest.fromLocalMap(Map<String, dynamic> data) {
    return ReturnRequest(
      id: data['id'] ?? '',
      orderId: data['orderId'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => ReturnItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      dateCreated: DateTime.parse(data['dateCreated']),
      dateUpdated: data['dateUpdated'] != null
          ? DateTime.parse(data['dateUpdated'])
          : null,
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
      refundMethod: data['refundMethod'] ?? 'original',
      customerId: data['customerId'],
      customerInfo: data['customerInfo'] != null
          ? Map<String, dynamic>.from(data['customerInfo'])
          : null,
      processedBy: data['processedBy'],
      isOffline: data['isOffline'] ?? false,
      offlineId: data['offlineId'],
      syncStatus: data['syncStatus'] ?? 'pending',
    );
  }

  ReturnRequest copyWith({
    String? status,
    String? notes,
    double? refundAmount,
    String? refundMethod,
    String? processedBy,
    String? syncStatus,
  }) {
    return ReturnRequest(
      id: id,
      orderId: orderId,
      orderNumber: orderNumber,
      items: items,
      reason: reason,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      dateCreated: dateCreated,
      dateUpdated: DateTime.now(),
      refundAmount: refundAmount ?? this.refundAmount,
      refundMethod: refundMethod ?? this.refundMethod,
      customerId: customerId,
      customerInfo: customerInfo,
      processedBy: processedBy ?? this.processedBy,
      isOffline: isOffline,
      offlineId: offlineId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ReturnCreationResult {
  final bool success;
  final ReturnRequest? returnRequest;
  final String? pendingReturnId;
  final String? error;

  ReturnCreationResult.success(this.returnRequest)
    : success = true,
      pendingReturnId = null,
      error = null;

  ReturnCreationResult.offline(this.pendingReturnId)
    : success = true,
      returnRequest = null,
      error = null;

  ReturnCreationResult.error(this.error)
    : success = false,
      returnRequest = null,
      pendingReturnId = null;

  bool get isOffline => pendingReturnId != null;
}

/// Firestore Service - Replaces WooCommerce
class FirestoreService {
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }

  // Updated collection references with tenant isolation
  CollectionReference get productsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('products');

  CollectionReference get ordersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('orders');

  CollectionReference get categoriesRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('categories');

  CollectionReference get pendingOrdersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('pending_orders');

  CollectionReference get customersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customers');

  CollectionReference get returnsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('returns');
  static final FirestoreService _instance = FirestoreService._internal();
  // Add to FirestoreService class
  // In FirestoreService class - REPLACE the existing return methods with these:
  // In FirestoreService - UPDATE the createReturn method to handle no-order returns:
  // In FirestoreService class, add these methods:
  Future<String> addCategory(Category category) async {
    try {
      final categoryData = category.toFirestore();
      final docRef = categoriesRef.doc(category.id);
      await docRef.set(categoryData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add category: $e');
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      final categoryData = category.toFirestore();
      await categoriesRef.doc(category.id).update(categoryData);
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await categoriesRef.doc(categoryId).delete();
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // Enhanced return operations with offline support
  Future<ReturnRequest> createReturn(ReturnRequest returnRequest) async {
    try {
      final returnRef = returnsRef.doc(returnRequest.id);
      final returnData = returnRequest.toFirestore();

      await returnRef.set(returnData);

      // Restock returned items - only if product exists in database
      for (final item in returnRequest.items) {
        try {
          final productDoc = await productsRef.doc(item.productId).get();
          if (productDoc.exists) {
            await productsRef.doc(item.productId).update({
              'stockQuantity': FieldValue.increment(item.quantity),
              'dateModified': FieldValue.serverTimestamp(),
            });
          } else {
            print(
              'Product ${item.productId} not found in database, skipping stock update',
            );
          }
        } catch (e) {
          print('Error updating stock for product ${item.productId}: $e');
          // Continue with other products even if one fails
        }
      }

      // Update order status only if it's a real order (not 'no_order')
      if (returnRequest.orderId != 'no_order') {
        try {
          final orderDoc = await ordersRef.doc(returnRequest.orderId).get();
          if (orderDoc.exists) {
            await ordersRef.doc(returnRequest.orderId).update({
              'hasReturns': true,
              'dateModified': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          print('Error updating order status: $e');
        }
      }

      return returnRequest;
    } catch (e) {
      print('Failed to create return: $e');
      throw Exception('Failed to create return: $e');
    }
  }

  Future<void> updateReturnStatus(
    String returnId,
    String status, {
    String? processedBy,
  }) async {
    try {
      final updateData = {
        'status': status,
        'dateUpdated': FieldValue.serverTimestamp(),
      };

      if (processedBy != null) {
        updateData['processedBy'] = processedBy;
      }

      await returnsRef.doc(returnId).update(updateData);
    } catch (e) {
      print('Error updating return status: $e');
      throw Exception('Failed to update return status: $e');
    }
  }

  Future<List<ReturnRequest>> getReturnsByOrder(String orderId) async {
    try {
      final snapshot = await returnsRef
          .where('orderId', isEqualTo: orderId)
          .orderBy('dateCreated', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return ReturnRequest.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error getting returns by order: $e');
      return [];
    }
  }

  Stream<List<ReturnRequest>> getReturnsStream() {
    return returnsRef
        .orderBy('dateCreated', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return ReturnRequest.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList(),
        );
  }

  Future<List<ReturnRequest>> getAllReturns({int limit = 50}) async {
    try {
      final snapshot = await returnsRef
          .orderBy('dateCreated', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return ReturnRequest.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error getting all returns: $e');
      return [];
    }
  }

  Future<bool> syncPendingReturn(Map<String, dynamic> pendingReturn) async {
    try {
      final returnRequest = ReturnRequest.fromLocalMap(pendingReturn);

      // Create the return in Firestore
      await createReturn(returnRequest);

      return true;
    } catch (e) {
      print('Failed to sync pending return: $e');
      return false;
    }
  }

  Future<List<Order>> searchOrders(String query) async {
    if (query.isEmpty) return [];

    try {
      final snapshot = await ordersRef
          .where('number', isGreaterThanOrEqualTo: query)
          .where('number', isLessThanOrEqualTo: '$query\uf8ff')
          .orderBy('number')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Order.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error searching orders: $e');
      return [];
    }
  }

  Future<Order?> getOrderById(String orderId) async {
    try {
      final doc = await ordersRef.doc(orderId).get();
      if (doc.exists) {
        return Order.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }
  // In FirestoreService class - REPLACE the existing return methods with these:

  Future<List<Order>> getRecentOrders({int limit = 50}) async {
    try {
      final snapshot = await ordersRef
          .orderBy('dateCreated', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Order.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting recent orders: $e');
      return [];
    }
  }

  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Customer operations
  Stream<List<Customer>> getCustomersStream() {
    return customersRef
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Customer.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) return [];

    final snapshot = await customersRef
        .where('searchKeywords', arrayContains: query.toLowerCase())
        .limit(20)
        .get();

    return snapshot.docs
        .map(
          (doc) => Customer.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final doc = await customersRef.doc(id).get();
    if (doc.exists) {
      return Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<Customer?> getCustomerByEmail(String email) async {
    final snapshot = await customersRef
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<String> addCustomer(Customer customer) async {
    try {
      final customerData = customer.toFirestore();
      final docRef = customersRef.doc();
      await docRef.set(customerData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add customer: $e');
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      final customerData = customer.toFirestore();
      await customersRef.doc(customer.id).update(customerData);
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  Future<void> updateCustomerStats(String customerId, double orderTotal) async {
    try {
      await customersRef.doc(customerId).update({
        'orderCount': FieldValue.increment(1),
        'totalSpent': FieldValue.increment(orderTotal),
        'dateModified': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to update customer stats: $e');
    }
  }

  // Enhanced order creation with customer support
  Future<Order> createOrderWithCustomer(
    List<CartItem> cartItems,
    CustomerSelection customerSelection,
  ) async {
    try {
      final orderRef = ordersRef.doc();
      final orderData = {
        'id': orderRef.id,
        'number': _generateOrderNumber(),
        'status': 'completed',
        'dateCreated': FieldValue.serverTimestamp(),
        'total': cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
        'lineItems': cartItems
            .map(
              (item) => {
                'productId': item.product.id,
                'productName': item.product.name,
                'quantity': item.quantity,
                'price': item.product.price,
                'subtotal': item.subtotal,
              },
            )
            .toList(),
        'paymentMethod': 'cash',
        'paymentStatus': 'paid',
      };

      // Add customer information if available
      if (customerSelection.hasCustomer) {
        orderData['customerId'] = customerSelection.customer!.id;
        orderData['customer'] = {
          'firstName': customerSelection.customer!.firstName,
          'lastName': customerSelection.customer!.lastName,
          'email': customerSelection.customer!.email,
          'phone': customerSelection.customer!.phone,
          'company': customerSelection.customer!.company,
        };
      }

      await orderRef.set(orderData);

      // Update stock quantities
      for (final item in cartItems) {
        await productsRef.doc(item.product.id).update({
          'stockQuantity': FieldValue.increment(-item.quantity),
        });
      }

      // Update customer stats if customer is associated
      if (customerSelection.hasCustomer) {
        await updateCustomerStats(
          customerSelection.customer!.id,
          cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
        );
      }

      return Order.fromFirestore(orderData, orderRef.id);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // Product operations
  Stream<List<Product>> getProductsStream() {
    return productsRef
        .where('status', isEqualTo: 'publish')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Product.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<List<Product>> getProducts({
    int limit = 50,
    String? lastDocumentId,
    String searchQuery = '',
    bool inStockOnly = false,
    double minPrice = 0,
    double maxPrice = double.infinity,
  }) async {
    Query query = productsRef
        .where('status', isEqualTo: 'publish')
        .orderBy('name')
        .limit(limit);

    if (lastDocumentId != null) {
      final lastDoc = await productsRef.doc(lastDocumentId).get();
      query = query.startAfterDocument(lastDoc);
    }

    if (searchQuery.isNotEmpty) {
      query = query.where(
        'searchKeywords',
        arrayContains: searchQuery.toLowerCase(),
      );
    }

    if (inStockOnly) {
      query = query.where('inStock', isEqualTo: true);
    }

    if (minPrice > 0) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }

    if (maxPrice < double.infinity) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<Product?> getProductById(String id) async {
    final doc = await productsRef.doc(id).get();
    if (doc.exists) {
      return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<Product?> getProductBySku(String sku) async {
    final snapshot = await productsRef
        .where('sku', isEqualTo: sku)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    final snapshot = await productsRef
        .where('searchKeywords', arrayContains: query.toLowerCase())
        .where('status', isEqualTo: 'publish')
        .limit(20)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<List<Product>> searchProductsBySKU(String sku) async {
    final snapshot = await productsRef
        .where('sku', isEqualTo: sku)
        .where('status', isEqualTo: 'publish')
        .limit(1)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // Product management
  Future<String> addProduct(Product product, List<XFile>? images) async {
    try {
      List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        for (final image in images) {
          final url = await _uploadImage(image, product.id);
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      final productData = product.toFirestore();
      productData['imageUrls'] = imageUrls;
      if (imageUrls.isNotEmpty) {
        productData['imageUrl'] = imageUrls.first;
      }

      productData['searchKeywords'] = _generateSearchKeywords(product);

      await productsRef.doc(product.id).set(productData);
      return product.id;
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  Future<void> updateProduct(Product product, List<XFile>? newImages) async {
    try {
      List<String> imageUrls = List.from(product.imageUrls);
      if (newImages != null && newImages.isNotEmpty) {
        for (final image in newImages) {
          final url = await _uploadImage(image, product.id);
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      final productData = product.toFirestore();
      productData['imageUrls'] = imageUrls;
      if (imageUrls.isNotEmpty && product.imageUrl == null) {
        productData['imageUrl'] = imageUrls.first;
      }
      productData['searchKeywords'] = _generateSearchKeywords(product);

      await productsRef.doc(product.id).update(productData);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await productsRef.doc(productId).update({'status': 'trash'});
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> restockProduct(
    String productId,
    int quantity, {
    String? barcode,
  }) async {
    try {
      await productsRef.doc(productId).update({
        'stockQuantity': FieldValue.increment(quantity),
        'inStock': true,
        'stockStatus': 'instock',
        'lastRestocked': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to restock product: $e');
    }
  }

  Future<String?> _uploadImage(XFile image, String productId) async {
    try {
      final File file = File(image.path);
      final String fileName =
          '${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('products/$fileName');

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Image upload failed: $e');
      return null;
    }
  }

  List<String> _generateSearchKeywords(Product product) {
    final keywords = <String>[];

    keywords.addAll(product.name.toLowerCase().split(' '));

    if (product.sku.isNotEmpty) {
      keywords.add(product.sku.toLowerCase());
    }

    for (final category in product.categories) {
      keywords.addAll(category.name.toLowerCase().split(' '));
    }

    return keywords.where((k) => k.length > 1).toSet().toList();
  }

  // Order operations
  Future<Order> createOrder(List<CartItem> cartItems) async {
    try {
      final orderRef = ordersRef.doc();
      final orderData = {
        'id': orderRef.id,
        'number': _generateOrderNumber(),
        'status': 'completed',
        'dateCreated': FieldValue.serverTimestamp(),
        'total': cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
        'lineItems': cartItems
            .map(
              (item) => {
                'productId': item.product.id,
                'productName': item.product.name,
                'quantity': item.quantity,
                'price': item.product.price,
                'subtotal': item.subtotal,
              },
            )
            .toList(),
        'paymentMethod': 'cash',
        'paymentStatus': 'paid',
      };

      await orderRef.set(orderData);

      for (final item in cartItems) {
        await productsRef.doc(item.product.id).update({
          'stockQuantity': FieldValue.increment(-item.quantity),
        });
      }

      return Order.fromFirestore(orderData, orderRef.id);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    return 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch}';
  }

  // Category operations
  Stream<List<Category>> getCategoriesStream() {
    return categoriesRef
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Category.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<List<Category>> getCategories() async {
    final snapshot = await categoriesRef.orderBy('name').get();
    return snapshot.docs
        .map(
          (doc) => Category.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  // Test connection
  Future<bool> testConnection() async {
    try {
      await productsRef.limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Enhanced POS Service with Offline Support
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  _CategoryManagementScreenState createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _posService.getCategories();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      print('Failed to load categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load categories: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Category Name *',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter category name')),
                );
                return;
              }

              try {
                final category = Category(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  slug: nameController.text.trim().toLowerCase().replaceAll(
                    ' ',
                    '-',
                  ),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  count: 0,
                );

                await _posService.addCategory(category);
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Category "${category.name}" added successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to add category: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No Categories Yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Add categories to organize your products',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: Icon(Icons.add),
              label: Text('Add First Category'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category, color: Colors.blue),
            ),
            title: Text(
              category.name,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category.description != null) Text(category.description!),
                SizedBox(height: 4),
                Text(
                  '${category.count} products',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(category),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Note: You'll need to implement deleteCategory in your POS service
                // await _posService.deleteCategory(category.id);
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete category: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Categories'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddCategoryDialog,
            tooltip: 'Add Category',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildCategoryList(),
    );
  }
}

/// Enhanced POS Service with Offline Support
class EnhancedPOSService {
  final FirestoreService _firestore = FirestoreService();

  void setTenantContext(String tenantId) {
    _firestore.setTenantId(tenantId);
  }

  Future<OrderCreationResult> createOrderWithCustomer(
    List<CartItem> cartItems,
    CustomerSelection customerSelection, {
    Map<String, dynamic>? additionalData,
  }) async {
    if (_isOnline) {
      try {
        final order = await _firestore.createOrderWithCustomer(
          cartItems,
          customerSelection,
        );

        // Apply additional data if provided
        if (additionalData != null) {
          await _firestore.ordersRef.doc(order.id).update({
            'additionalData': additionalData,
            'dateModified': FieldValue.serverTimestamp(),
          });
        }

        return OrderCreationResult.success(order);
      } catch (e) {
        print('Online order creation failed, saving locally: $e');
        return await _createOfflineOrderWithCustomer(
          cartItems,
          customerSelection,
          additionalData: additionalData,
        );
      }
    } else {
      return await _createOfflineOrderWithCustomer(
        cartItems,
        customerSelection,
        additionalData: additionalData,
      );
    }
  }

  Future<OrderCreationResult> _createOfflineOrderWithCustomer(
    List<CartItem> cartItems,
    CustomerSelection customerSelection, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Update local stock quantities
      for (final item in cartItems) {
        await _updateLocalProductStock(item.product.id, -item.quantity);
      }

      final pendingOrderId = await _localDb.savePendingOrderWithCustomer(
        cartItems,
        customerSelection,
        additionalData: additionalData,
      );
      await _localDb.clearCart();
      return OrderCreationResult.offline(pendingOrderId);
    } catch (e) {
      return OrderCreationResult.error('Failed to save order locally: $e');
    }
  }

  // Get invoice settings
  Future<Map<String, dynamic>> getInvoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'defaultTemplate':
          prefs.getString('default_invoice_template') ?? 'traditional',
      'taxRate': prefs.getDouble('tax_rate') ?? 0.0,
      'discountRate': prefs.getDouble('discount_rate') ?? 0.0,
      'autoPrint': prefs.getBool('auto_print') ?? false,
      'includeCustomerDetails':
          prefs.getBool('include_customer_details') ?? true,
      'defaultNotes':
          prefs.getString('default_notes') ?? 'Thank you for your business!',
    };
  }

  // Get business info
  Future<Map<String, dynamic>> getBusinessInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('business_name') ?? 'Your Business Name',
      'address': prefs.getString('business_address') ?? '',
      'phone': prefs.getString('business_phone') ?? '',
      'email': prefs.getString('business_email') ?? '',
      'website': prefs.getString('business_website') ?? '',
      'tagline': prefs.getString('business_tagline') ?? '',
      'taxNumber': prefs.getString('business_tax_number') ?? '',
    };
  }

  static final EnhancedPOSService _instance = EnhancedPOSService._internal();
  factory EnhancedPOSService() => _instance;
  EnhancedPOSService._internal();
  // In EnhancedPOSService class - REPLACE the existing return methods with these:
  // Enhanced Return operations with offline support
  Future<ReturnCreationResult> createReturn(ReturnRequest returnRequest) async {
    if (_isOnline) {
      try {
        final createdReturn = await _firestore.createReturn(returnRequest);
        // Save to local cache for offline access
        await _localDb.saveSyncedReturn(createdReturn);
        return ReturnCreationResult.success(createdReturn);
      } catch (e) {
        print('Online return creation failed, saving locally: $e');
        return await _createOfflineReturn(returnRequest);
      }
    } else {
      return await _createOfflineReturn(returnRequest);
    }
  }

  Future<ReturnCreationResult> _createOfflineReturn(
    ReturnRequest returnRequest,
  ) async {
    try {
      // Update local stock quantities for consistency
      for (final item in returnRequest.items) {
        await _updateLocalProductStock(item.productId, item.quantity);
      }

      final pendingReturnId = await _localDb.savePendingReturn(returnRequest);
      return ReturnCreationResult.offline(pendingReturnId.toString());
    } catch (e) {
      return ReturnCreationResult.error('Failed to save return locally: $e');
    }
  }

  Future<List<ReturnRequest>> getReturnsByOrder(String orderId) async {
    if (_isOnline) {
      try {
        final returns = await _firestore.getReturnsByOrder(orderId);
        // Cache the returns locally
        for (final returnReq in returns) {
          await _localDb.saveSyncedReturn(returnReq);
        }
        return returns;
      } catch (e) {
        print('Online fetch failed, using local data: $e');
        // Fall back to local data
        final allReturns = await _localDb.getAllReturns();
        return allReturns.where((ret) => ret.orderId == orderId).toList();
      }
    } else {
      final allReturns = await _localDb.getAllReturns();
      return allReturns.where((ret) => ret.orderId == orderId).toList();
    }
  }

  Stream<List<ReturnRequest>> getReturnsStream() {
    if (_isOnline) {
      return _firestore.getReturnsStream();
    } else {
      // Return a stream from local data
      return Stream.fromFuture(_localDb.getAllReturns());
    }
  }

  Future<List<ReturnRequest>> getAllReturns({int limit = 50}) async {
    if (_isOnline) {
      try {
        final returns = await _firestore.getAllReturns(limit: limit);
        // Cache returns locally
        for (final returnReq in returns) {
          await _localDb.saveSyncedReturn(returnReq);
        }
        return returns;
      } catch (e) {
        print('Online fetch failed, using local data: $e');
        return await _localDb.getAllReturns();
      }
    } else {
      return await _localDb.getAllReturns();
    }
  }

  Future<void> updateReturnStatus(
    String returnId,
    String status, {
    String? processedBy,
  }) async {
    if (_isOnline) {
      try {
        await _firestore.updateReturnStatus(
          returnId,
          status,
          processedBy: processedBy,
        );
      } catch (e) {
        print('Online status update failed: $e');
        throw Exception('Failed to update return status online: $e');
      }
    } else {
      throw Exception('Cannot update return status while offline');
    }
  }

  // Enhanced sync method to include returns
  Future<void> _syncPendingReturns() async {
    final pendingReturns = await _localDb.getPendingReturns();

    if (pendingReturns.isEmpty) {
      print('No pending returns to sync');
      return;
    }

    print('Syncing ${pendingReturns.length} pending returns...');

    for (final pendingReturn in pendingReturns) {
      try {
        final success = await _firestore.syncPendingReturn(pendingReturn);

        if (success) {
          await _localDb.deletePendingReturn(pendingReturn['local_id']);
          print(
            'Successfully synced pending return ${pendingReturn['local_id']}',
          );
        } else {
          await _localDb.updatePendingReturnStatus(
            pendingReturn['local_id'],
            'failed',
          );
          print('Failed to sync pending return ${pendingReturn['local_id']}');
        }
      } catch (e) {
        print('Error syncing pending return ${pendingReturn['local_id']}: $e');
        final attempts = (pendingReturn['sync_attempts'] as int? ?? 0) + 1;

        if (attempts >= 3) {
          await _localDb.updatePendingReturnStatus(
            pendingReturn['local_id'],
            'failed',
            attempts: attempts,
          );
        } else {
          await _localDb.updatePendingReturnStatus(
            pendingReturn['local_id'],
            'pending',
            attempts: attempts,
          );
        }
      }
    }
  }

  // Update the main sync method to include returns
  Future<void> _triggerSync() async {
    await _syncLock.synchronized(() async {
      try {
        await _syncPendingOrders();
        await _syncPendingRestocks();
        await _syncPendingReturns(); // Add this line
        await _syncProducts();
      } catch (e) {
        print('Sync error: $e');
      }
    });
  }
  // Enhanced Return operations

  // Add to EnhancedPOSService class
  Future<List<Order>> searchOrders(String query) async {
    return await _firestore.searchOrders(query);
  }

  Future<Order?> getOrderById(String orderId) async {
    return await _firestore.getOrderById(orderId);
  }

  Future<List<Order>> getRecentOrders({int limit = 50}) async {
    return await _firestore.getRecentOrders(limit: limit);
  }

  // Customer management methods
  Future<List<Customer>> searchCustomers(String query) async {
    return await _firestore.searchCustomers(query);
  }

  Future<List<Customer>> getAllCustomers() async {
    try {
      if (_isOnline) {
        // Get all customers from Firestore
        final snapshot = await _firestore.customersRef
            .orderBy('firstName')
            .get();

        final customers = snapshot.docs
            .map(
              (doc) => Customer.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();

        // Save to local cache for offline use
        await _localDb.saveCustomers(customers);
        return customers;
      } else {
        // Get customers from local database when offline
        return await _localDb.getCustomers();
      }
    } catch (e) {
      print('Error getting all customers: $e');
      // Fallback to local data if online fetch fails
      return await _localDb.getCustomers();
    }
  }

  Future<Customer?> getCustomerById(String id) async {
    return await _firestore.getCustomerById(id);
  }

  Future<Customer?> getCustomerByEmail(String email) async {
    return await _firestore.getCustomerByEmail(email);
  }

  Future<String> addCustomer(Customer customer) async {
    return await _firestore.addCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _firestore.updateCustomer(customer);
  }

  // Enhanced order creation

  final LocalDatabase _localDb = LocalDatabase();
  final Connectivity _connectivity = Connectivity();
  final Lock _syncLock = Lock();

  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void initialize() {
    _startConnectivityListener();
    _checkInitialConnection();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  // In EnhancedPOSService class - ADD this method
  Future<void> refreshLocalCache() async {
    if (_isOnline) {
      try {
        // Clear existing cache and fetch fresh data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(LocalDatabase._productsKey);

        // Fetch fresh products
        await _syncProducts();
      } catch (e) {
        print('Error refreshing local cache: $e');
      }
    }
  }

  Future<void> _startConnectivityListener() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> resultList,
    ) {
      final wasOnline = _isOnline;
      _isOnline = resultList.any((res) => res != ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        _triggerSync();
        refreshLocalCache(); // Add this line
      }
    });
  }

  Future<void> _checkInitialConnection() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    if (_isOnline) {
      _triggerSync();
    }
  }

  Stream<List<Product>> getProductsStream() {
    if (_isOnline) {
      return _firestore.getProductsStream();
    } else {
      return Stream.value([]);
    }
  }

  Future<List<Product>> fetchProducts({
    int limit = 50,
    String? lastDocumentId,
    String searchQuery = '',
    bool inStockOnly = false,
    double minPrice = 0,
    double maxPrice = double.infinity,
  }) async {
    if (_isOnline) {
      try {
        final products = await _firestore.getProducts(
          limit: limit,
          lastDocumentId: lastDocumentId,
          searchQuery: searchQuery,
          inStockOnly: inStockOnly,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );
        await _localDb.saveProducts(products);
        return products;
      } catch (e) {
        print('Online fetch failed, using local data: $e');
        return await _localDb.getProducts(
          limit: limit,
          searchQuery: searchQuery,
          inStockOnly: inStockOnly,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );
      }
    } else {
      return await _localDb.getProducts(
        limit: limit,
        searchQuery: searchQuery,
        inStockOnly: inStockOnly,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    if (_isOnline) {
      try {
        final products = await _firestore.searchProducts(query);
        if (products.isNotEmpty) {
          await _localDb.saveProducts(products);
        }
        return products;
      } catch (e) {
        print('Online search failed, using local data: $e');
        return await _localDb.getProducts(searchQuery: query);
      }
    } else {
      return await _localDb.getProducts(searchQuery: query);
    }
  }

  Future<List<Product>> searchProductsBySKU(String sku) async {
    final localProduct = await _localDb.getProductBySku(sku);
    if (localProduct != null) {
      return [localProduct];
    }

    if (_isOnline) {
      try {
        final products = await _firestore.searchProductsBySKU(sku);
        if (products.isNotEmpty) {
          await _localDb.saveProducts(products);
        }
        return products;
      } catch (e) {
        print('Online SKU search failed: $e');
        return [];
      }
    } else {
      return [];
    }
  }

  Future<OrderCreationResult> createOrder(List<CartItem> cartItems) async {
    if (_isOnline) {
      try {
        final order = await _firestore.createOrder(cartItems);
        return OrderCreationResult.success(order);
      } catch (e) {
        print('Online order creation failed, saving locally: $e');
        return await _createOfflineOrder(cartItems);
      }
    } else {
      return await _createOfflineOrder(cartItems);
    }
  }

  Future<OrderCreationResult> _createOfflineOrder(
    List<CartItem> cartItems,
  ) async {
    try {
      // Update local stock quantities first for offline consistency
      for (final item in cartItems) {
        await _updateLocalProductStock(item.product.id, -item.quantity);
      }

      final pendingOrderId = await _localDb.savePendingOrder(cartItems);
      await _localDb.clearCart();
      return OrderCreationResult.offline(pendingOrderId);
    } catch (e) {
      return OrderCreationResult.error('Failed to save order locally: $e');
    }
  }

  Future<void> _syncPendingOrders() async {
    final pendingOrders = await _localDb.getPendingOrders();

    if (pendingOrders.isEmpty) {
      print('No pending orders to sync');
      return;
    }

    print('Syncing ${pendingOrders.length} pending orders...');

    for (final order in pendingOrders) {
      try {
        final orderData = order['order_data'] as Map<String, dynamic>;
        final lineItems = (orderData['line_items'] as List).map((item) {
          return CartItem(
            product: Product(
              id: item['product_id'].toString(),
              name: item['product_name']?.toString() ?? '',
              sku: item['product_sku']?.toString() ?? '',
              price: (item['price'] as num).toDouble(),
              stockQuantity: 0,
              inStock: true,
              stockStatus: 'instock',
            ),
            quantity: item['quantity'],
          );
        }).toList();

        final createdOrder = await _firestore.createOrder(lineItems);
        await _localDb.deletePendingOrder(order['id']);

        print(
          'Successfully synced pending order ${order['id']} as order ${createdOrder.id}',
        );
      } catch (e) {
        print('Failed to sync pending order ${order['id']}: $e');
        final attempts = (order['sync_attempts'] as int? ?? 0) + 1;

        if (attempts >= 3) {
          await _localDb.updatePendingOrderStatus(
            order['id'],
            'failed',
            attempts: attempts,
          );
        } else {
          await _localDb.updatePendingOrderStatus(
            order['id'],
            'pending',
            attempts: attempts,
          );
        }
      }
    }
  }

  Future<void> _syncPendingRestocks() async {
    final pendingRestocks = await _localDb.getPendingRestocks();

    if (pendingRestocks.isEmpty) {
      print('No pending restocks to sync');
      return;
    }

    print('Syncing ${pendingRestocks.length} pending restocks...');

    for (final restock in pendingRestocks) {
      try {
        await _firestore.restockProduct(
          restock['productId'].toString(),
          restock['quantity'] as int,
          barcode: restock['barcode']?.toString(),
        );
        await _localDb.deletePendingRestock(restock['id']);
        print(
          'Successfully synced restock for product ${restock['productId']}',
        );
      } catch (e) {
        print('Failed to sync restock ${restock['id']}: $e');
        final attempts = (restock['sync_attempts'] as int? ?? 0) + 1;

        if (attempts >= 3) {
          await _localDb.updatePendingRestockStatus(
            restock['id'],
            'failed',
            attempts: attempts,
          );
        } else {
          await _localDb.updatePendingRestockStatus(
            restock['id'],
            'pending',
            attempts: attempts,
          );
        }
      }
    }
  }

  Future<void> _syncProducts() async {
    try {
      final products = await _firestore.getProducts(limit: 50);
      await _localDb.saveProducts(products);
      print('Successfully synced ${products.length} products');
    } catch (e) {
      print('Product sync failed: $e');
    }
  }

  Future<void> manualSync() async {
    if (_isOnline) {
      await _triggerSync();
    }
  }

  // Product management methods
  Future<String> addProduct(Product product, List<XFile>? images) async {
    return await _firestore.addProduct(product, images);
  }

  Future<void> updateProduct(Product product, List<XFile>? newImages) async {
    await _firestore.updateProduct(product, newImages);
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.deleteProduct(productId);
  }

  Future<void> restockProduct(
    String productId,
    int quantity, {
    String? barcode,
  }) async {
    if (_isOnline) {
      try {
        await _firestore.restockProduct(productId, quantity, barcode: barcode);
        // Update local cache after successful online restock
        await _syncLocalProductAfterRestock(productId, quantity);
      } catch (e) {
        // Fallback to offline mode
        await _savePendingRestock(productId, quantity, barcode);
        throw Exception('Online restock failed. Saved offline: $e');
      }
    } else {
      // Save restock operation for later sync
      await _savePendingRestock(productId, quantity, barcode);
    }
  }

  Future<void> _savePendingRestock(
    String productId,
    int quantity,
    String? barcode,
  ) async {
    await _localDb.savePendingRestock(productId, quantity, barcode);
    // Also update local product cache immediately for offline use
    await _updateLocalProductStock(productId, quantity);
  }

  // In EnhancedPOSService class - ENHANCE the _updateLocalProductStock method
  Future<void> _updateLocalProductStock(String productId, int quantity) async {
    final products = await _localDb.getProducts(limit: 0); // Get all products
    final productIndex = products.indexWhere((p) => p.id == productId);

    if (productIndex != -1) {
      final product = products[productIndex];
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        sku: product.sku,
        price: product.price,
        regularPrice: product.regularPrice,
        salePrice: product.salePrice,
        imageUrl: product.imageUrl,
        imageUrls: product.imageUrls,
        stockQuantity: product.stockQuantity + quantity,
        inStock: (product.stockQuantity + quantity) > 0,
        stockStatus: (product.stockQuantity + quantity) > 0
            ? 'instock'
            : 'outofstock',
        description: product.description,
        shortDescription: product.shortDescription,
        categories: product.categories,
        attributes: product.attributes,
        metaData: product.metaData,
        dateCreated: product.dateCreated,
        dateModified: DateTime.now(),
        purchasable: product.purchasable,
        type: product.type,
        status: product.status,
        featured: product.featured,
        permalink: product.permalink,
        averageRating: product.averageRating,
        ratingCount: product.ratingCount,
        parentId: product.parentId,
        variations: product.variations,
        weight: product.weight,
        dimensions: product.dimensions,
      );

      // Save only the updated product - the saveProducts method will now merge it
      await _localDb.saveProducts([updatedProduct]);
    }
  }

  Future<void> _syncLocalProductAfterRestock(
    String productId,
    int quantity,
  ) async {
    await _updateLocalProductStock(productId, quantity);
  }

  Stream<List<Category>> getCategoriesStream() {
    return _firestore.getCategoriesStream();
  }

  Future<List<Category>> getCategories() async {
    return await _firestore.getCategories();
  }

  Future<String> addCategory(Category category) async {
    return await _firestore.addCategory(category);
  }

  bool get isOnline => _isOnline;

  Stream<bool> get onlineStatusStream =>
      _connectivity.onConnectivityChanged.map(
        (List<ConnectivityResult> resultList) =>
            resultList.any((res) => res != ConnectivityResult.none),
      );

  Future<bool> testConnection() async {
    return _firestore.testConnection();
  }
}

// Data Models

class CartItem {
  final Product product;
  int quantity;
  double? manualDiscount; // Manual discount amount for this specific item
  double?
  manualDiscountPercent; // Manual discount percentage for this specific item

  CartItem({
    required this.product,
    required this.quantity,
    this.manualDiscount,
    this.manualDiscountPercent,
  });

  double get baseSubtotal => product.price * quantity;

  double get discountAmount {
    if (manualDiscount != null) {
      return manualDiscount! * quantity;
    } else if (manualDiscountPercent != null) {
      return (product.price * manualDiscountPercent! / 100) * quantity;
    }
    return 0.0;
  }

  double get subtotal => baseSubtotal - discountAmount;

  bool get hasManualDiscount =>
      manualDiscount != null || manualDiscountPercent != null;
}

class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int count;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.count,
    this.imageUrl,
  });

  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      name: data['name']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      description: data['description']?.toString(),
      count: data['count'] ?? 0,
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'count': count,
      'imageUrl': imageUrl,
    };
  }
}

class Attribute {
  final int id;
  final String name;
  final String slug;
  final List<String> options;
  final bool visible;
  final bool variation;

  Attribute({
    required this.id,
    required this.name,
    required this.slug,
    required this.options,
    required this.visible,
    required this.variation,
  });

  factory Attribute.fromFirestore(Map<String, dynamic> data, int id) {
    final List<String> parsedOptions = [];
    if (data['options'] is List) {
      for (var option in data['options']) {
        if (option != null) {
          parsedOptions.add(option.toString());
        }
      }
    }

    return Attribute(
      id: id,
      name: data['name']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      options: parsedOptions,
      visible: data['visible'] ?? false,
      variation: data['variation'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'options': options,
      'visible': visible,
      'variation': variation,
    };
  }
}

class Order {
  final String id;
  final String number;
  final DateTime dateCreated;
  final double total;
  final List<dynamic> lineItems;

  Order({
    required this.id,
    required this.number,
    required this.dateCreated,
    required this.total,
    required this.lineItems,
  });

  factory Order.fromFirestore(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      number: data['number'] ?? '',
      dateCreated: data['dateCreated'] is Timestamp
          ? (data['dateCreated'] as Timestamp).toDate()
          : DateTime.now(),
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      lineItems: data['lineItems'] ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'number': number,
      'dateCreated': Timestamp.fromDate(dateCreated),
      'total': total,
      'lineItems': lineItems,
      // Add additional fields that might be stored in your Firestore orders
      'subtotal': _calculateSubtotal(),
      'totalDiscount': _calculateTotalDiscount(),
      'itemDiscounts': _calculateItemDiscounts(),
      'cartDiscount': _calculateCartDiscount(),
      'additionalDiscount': _calculateAdditionalDiscount(),
      'taxAmount': _calculateTaxAmount(),
      'shippingAmount': _calculateShippingAmount(),
      'tipAmount': _calculateTipAmount(),
      'taxableAmount': _calculateTaxableAmount(),
      'paymentMethod': _getPaymentMethod(),
    };
  }

  // Helper methods to calculate financial values
  double _calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        subtotal += quantity * price;
      }
    }
    return subtotal;
  }

  double _calculateTotalDiscount() {
    // This would be the sum of all discounts applied to the order
    // You might need to adjust this based on how you store discounts
    double totalDiscount = 0.0;

    // Item-level discounts
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        final discount = (item['discountAmount'] as num?)?.toDouble() ?? 0.0;
        totalDiscount += discount;
      }
    }

    // Add cart-level discounts if stored separately
    // totalDiscount += (cartDiscount ?? 0.0);
    // totalDiscount += (additionalDiscount ?? 0.0);

    return totalDiscount;
  }

  double _calculateItemDiscounts() {
    double itemDiscounts = 0.0;
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        final discount = (item['discountAmount'] as num?)?.toDouble() ?? 0.0;
        itemDiscounts += discount;
      }
    }
    return itemDiscounts;
  }

  double _calculateCartDiscount() {
    // This would return cart-level discounts
    // You might need to store this separately in your order data
    return 0.0; // Replace with actual cart discount calculation
  }

  double _calculateAdditionalDiscount() {
    // This would return additional discounts applied at checkout
    // You might need to store this separately in your order data
    return 0.0; // Replace with actual additional discount calculation
  }

  double _calculateTaxAmount() {
    // Calculate tax amount based on your business logic
    // This might be stored separately or calculated from taxable amount and tax rate
    final subtotal = _calculateSubtotal();
    final discounts = _calculateTotalDiscount();
    final taxableAmount = subtotal - discounts;

    // Assuming a default tax rate of 10% - adjust based on your needs
    const taxRate = 0.10;
    return taxableAmount * taxRate;
  }

  double _calculateShippingAmount() {
    // Return shipping amount if stored in order data
    return 0.0; // Replace with actual shipping amount
  }

  double _calculateTipAmount() {
    // Return tip amount if stored in order data
    return 0.0; // Replace with actual tip amount
  }

  double _calculateTaxableAmount() {
    final subtotal = _calculateSubtotal();
    final discounts = _calculateTotalDiscount();
    return subtotal - discounts;
  }

  String _getPaymentMethod() {
    // Return payment method if stored in order data
    return 'cash'; // Replace with actual payment method from order data
  }
}
class OrderCreationResult {
  final bool success;
  final Order? order;
  final int? pendingOrderId;
  final String? error;

  OrderCreationResult.success(this.order)
    : success = true,
      pendingOrderId = null,
      error = null;

  OrderCreationResult.offline(this.pendingOrderId)
    : success = true,
      order = null,
      error = null;

  OrderCreationResult.error(this.error)
    : success = false,
      order = null,
      pendingOrderId = null;

  bool get isOffline => pendingOrderId != null;
}

// Local Database for Offline Support (using shared_preferences)
// Local Database for Offline Support (using shared_preferences)
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static const String _dashboardDataKey = 'dashboard_data';
  static const String _dashboardCacheTimestampKey = 'dashboard_cache_timestamp';
  static const Duration _dashboardCacheDuration = Duration(hours: 1);

  // Dashboard operations
  Future<void> saveDashboardData(OfflineDashboardData data) async {
    final prefs = await _prefs;
    final dashboardData = data.toJson();
    await prefs.setString(_dashboardDataKey, json.encode(dashboardData));
    await prefs.setInt(
      _dashboardCacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<OfflineDashboardData?> getDashboardData(String tenantId) async {
    final prefs = await _prefs;
    final dashboardDataJson = prefs.getString(_dashboardDataKey);
    final timestamp = prefs.getInt(_dashboardCacheTimestampKey);

    if (dashboardDataJson == null || timestamp == null) {
      return null;
    }

    // Check if cache is still valid
    final lastUpdated = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(lastUpdated) > _dashboardCacheDuration) {
      return null;
    }

    try {
      final Map<String, dynamic> jsonData = json.decode(dashboardDataJson);
      final data = OfflineDashboardData.fromJson(jsonData);

      // Only return data if it's for the current tenant
      if (data.tenantId == tenantId) {
        return data;
      }
      return null;
    } catch (e) {
      print('Error loading cached dashboard data: $e');
      return null;
    }
  }

  Future<void> clearDashboardData() async {
    final prefs = await _prefs;
    await prefs.remove(_dashboardDataKey);
    await prefs.remove(_dashboardCacheTimestampKey);
  }

  // Helper method to check if we have recent dashboard data
  Future<bool> hasRecentDashboardData(String tenantId) async {
    final data = await getDashboardData(tenantId);
    return data != null;
  }

  // Enhanced product operations for dashboard
  Future<List<Product>> getLowStockProducts() async {
    final products = await getAllProducts();
    return products
        .where((product) => product.stockQuantity <= 10)
        .toList();
  }

  // Enhanced customer operations for dashboard
  Future<List<Customer>> getRecentCustomers({int limit = 5}) async {
    final customers = await getCustomers();
    customers.sort((a, b) => (b.dateCreated ?? DateTime(0)).compareTo(a.dateCreated ?? DateTime(0)));
    return customers.take(limit).toList();
  }

  // Generate revenue data from offline orders
  Future<List<RevenueDataPoint>> generateRevenueData() async {
    final pendingOrders = await getPendingOrders();
    final now = DateTime.now();
    final List<RevenueDataPoint> revenueData = [];

    // Generate last 7 days data
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      double dayRevenue = 0.0;
      int dayOrders = 0;

      // Calculate revenue from pending orders for this day
      for (final order in pendingOrders) {
        final orderDate = DateTime.parse(order['created_at']);
        if (orderDate.year == date.year &&
            orderDate.month == date.month &&
            orderDate.day == date.day) {
          final orderData = order['order_data'] as Map<String, dynamic>;
          dayRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
          dayOrders++;
        }
      }

      revenueData.add(RevenueDataPoint(
        date: date,
        revenue: dayRevenue,
        orders: dayOrders,
      ));
    }

    return revenueData;
  }

  // Generate top selling products from offline orders
  Future<List<TopSellingProduct>> generateTopSellingProducts() async {
    final pendingOrders = await getPendingOrders();
    final productSales = <String, TopSellingProduct>{};

    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      final lineItems = orderData['line_items'] as List<dynamic>? ?? [];

      for (final item in lineItems) {
        final itemMap = item as Map<String, dynamic>;
        final productId = itemMap['product_id']?.toString() ?? '';
        final productName = itemMap['product_name']?.toString() ?? 'Unknown Product';
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

        if (productId.isNotEmpty) {
          if (productSales.containsKey(productId)) {
            final existing = productSales[productId]!;
            productSales[productId] = TopSellingProduct(
              productId: productId,
              productName: productName,
              totalSold: existing.totalSold + quantity,
              totalRevenue: existing.totalRevenue + (price * quantity),
              imageUrl: existing.imageUrl,
            );
          } else {
            // Try to get product image from cached products
            String? imageUrl;
            try {
              final product = await getProductById(productId);
              imageUrl = product?.imageUrl;
            } catch (e) {
              print('Error getting product image: $e');
            }

            productSales[productId] = TopSellingProduct(
              productId: productId,
              productName: productName,
              totalSold: quantity,
              totalRevenue: price * quantity,
              imageUrl: imageUrl,
            );
          }
        }
      }
    }

    final sortedList = productSales.values.toList();
    sortedList.sort((a, b) => b.totalSold.compareTo(a.totalSold));
    return sortedList.take(5).toList();
  }

  // Generate dashboard stats from offline data
  Future<DashboardStats> generateOfflineStats() async {
    final pendingOrders = await getPendingOrders();
    final products = await getAllProducts();
    final customers = await getCustomers();
    final pendingReturns = await getPendingReturns();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Calculate today's orders and revenue
    double todayRevenue = 0.0;
    int todaySales = 0;
    final todayCustomerIds = <String>{};

    for (final order in pendingOrders) {
      final orderDate = DateTime.parse(order['created_at']);
      if (orderDate.isAfter(todayStart)) {
        final orderData = order['order_data'] as Map<String, dynamic>;
        todayRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
        todaySales++;

        // Track today's customers
        final customerData = order['customer_data'] as Map<String, dynamic>?;
        if (customerData != null && customerData['customerId'] != null) {
          todayCustomerIds.add(customerData['customerId'].toString());
        }
      }
    }

    // Calculate total revenue and sales
    double totalRevenue = 0.0;
    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      totalRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
    }

    // Calculate low stock products
    final lowStockProducts = products.where((p) => p.stockQuantity <= 10).length;

    // Calculate derived metrics
    final averageOrderValue = pendingOrders.isNotEmpty
        ? totalRevenue / pendingOrders.length
        : 0.0;
    final conversionRate = customers.isNotEmpty
        ? (pendingOrders.length / customers.length * 100).clamp(0.0, 100.0)
        : 0.0;

    // Calculate today's returns
    final todayReturns = pendingReturns.where((returnReq) {
      final returnDate = DateTime.parse(returnReq['created_at'] ?? '');
      return returnDate.isAfter(todayStart);
    }).length;

    return DashboardStats(
      totalRevenue: totalRevenue,
      todayRevenue: todayRevenue,
      totalSales: pendingOrders.length,
      todaySales: todaySales,
      totalProducts: products.length,
      lowStockProducts: lowStockProducts,
      totalCustomers: customers.length,
      todayCustomers: todayCustomerIds.length,
      averageOrderValue: averageOrderValue,
      conversionRate: conversionRate,
      revenueGrowth: 0.0, // Can't calculate growth offline
      salesGrowth: 0.0,   // Can't calculate growth offline
      todayReturns: todayReturns,
      totalReturns: pendingReturns.length,
    );
  }
  static const String _pendingReturnsKey = 'pending_returns';
  static const String _syncedReturnsKey = 'synced_returns';

  static const String _productsKey = 'cached_products';
  static const String _cartKey = 'cart_items';
  static const String _pendingOrdersKey = 'pending_orders';
  static const String _pendingRestocksKey = 'pending_restocks';
  static const String _cacheTimestampKey = 'cache_timestamp';

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();
  static const String _customersKey = 'cached_customers';

  // Return operations
  Future<int> savePendingReturn(ReturnRequest returnRequest) async {
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);
    final List<dynamic> pendingReturns = pendingReturnsJson != null
        ? json.decode(pendingReturnsJson)
        : [];

    final returnId = pendingReturns.length + 1;
    final offlineId = 'offline_return_${DateTime.now().millisecondsSinceEpoch}';

    final returnData = returnRequest.toLocalMap();
    returnData['local_id'] = returnId;
    returnData['offline_id'] = offlineId;
    returnData['sync_status'] = 'pending';
    returnData['sync_attempts'] = 0;
    returnData['created_at'] = DateTime.now().toIso8601String();

    pendingReturns.add(returnData);
    await prefs.setString(_pendingReturnsKey, json.encode(pendingReturns));

    return returnId;
  }

  Future<List<Map<String, dynamic>>> getPendingReturns() async {
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);

    if (pendingReturnsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(pendingReturnsJson);
      return jsonList
          .where((ret) => ret['sync_status'] == 'pending')
          .map((ret) => Map<String, dynamic>.from(ret))
          .toList();
    } catch (e) {
      print('Error loading pending returns: $e');
      return [];
    }
  }

  Future<void> updatePendingReturnStatus(
    int returnId,
    String status, {
    int attempts = 0,
  }) async {
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);

    if (pendingReturnsJson == null) return;

    try {
      final List<dynamic> pendingReturns = json.decode(pendingReturnsJson);
      for (var i = 0; i < pendingReturns.length; i++) {
        if (pendingReturns[i]['local_id'] == returnId) {
          pendingReturns[i]['sync_status'] = status;
          pendingReturns[i]['sync_attempts'] = attempts;
          pendingReturns[i]['last_sync_attempt'] = DateTime.now()
              .toIso8601String();
          break;
        }
      }
      await prefs.setString(_pendingReturnsKey, json.encode(pendingReturns));
    } catch (e) {
      print('Error updating pending return: $e');
    }
  }

  Future<void> deletePendingReturn(int returnId) async {
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);

    if (pendingReturnsJson == null) return;

    try {
      final List<dynamic> pendingReturns = json.decode(pendingReturnsJson);
      pendingReturns.removeWhere((ret) => ret['local_id'] == returnId);
      await prefs.setString(_pendingReturnsKey, json.encode(pendingReturns));
    } catch (e) {
      print('Error deleting pending return: $e');
    }
  }

  Future<void> saveSyncedReturn(ReturnRequest returnRequest) async {
    final prefs = await _prefs;
    final syncedReturnsJson = prefs.getString(_syncedReturnsKey);
    final List<dynamic> syncedReturns = syncedReturnsJson != null
        ? json.decode(syncedReturnsJson)
        : [];

    final returnData = returnRequest.toLocalMap();
    returnData['synced_at'] = DateTime.now().toIso8601String();

    syncedReturns.add(returnData);
    await prefs.setString(_syncedReturnsKey, json.encode(syncedReturns));
  }

  Future<List<ReturnRequest>> getSyncedReturns() async {
    final prefs = await _prefs;
    final syncedReturnsJson = prefs.getString(_syncedReturnsKey);

    if (syncedReturnsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(syncedReturnsJson);
      return jsonList
          .map(
            (json) =>
                ReturnRequest.fromLocalMap(Map<String, dynamic>.from(json)),
          )
          .toList();
    } catch (e) {
      print('Error loading synced returns: $e');
      return [];
    }
  }

  Future<List<ReturnRequest>> getAllReturns() async {
    final pending = await getPendingReturns();
    final synced = await getSyncedReturns();

    final allReturns = [
      ...pending.map((p) => ReturnRequest.fromLocalMap(p)),
      ...synced,
    ];

    // Sort by date created (newest first)
    allReturns.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

    return allReturns;
  }

  // Customer operations
  Future<void> saveCustomers(List<Customer> customers) async {
    final prefs = await _prefs;
    final customersJson = customers
        .map((customer) => customer.toFirestore())
        .toList();
    await prefs.setString(_customersKey, json.encode(customersJson));
  }

  Future<List<Customer>> getCustomers() async {
    final prefs = await _prefs;
    final customersJson = prefs.getString(_customersKey);

    if (customersJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(customersJson);
      return jsonList.map((json) {
        final id = json['id']?.toString() ?? '';
        return Customer.fromFirestore(json, id);
      }).toList();
    } catch (e) {
      print('Error loading cached customers: $e');
      return [];
    }
  }

  Future<int> savePendingOrderWithCustomer(
    List<CartItem> cartItems,
    CustomerSelection customerSelection, {
    Map<String, dynamic>? additionalData,
  }) async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);
    final List<dynamic> pendingOrders = pendingOrdersJson != null
        ? json.decode(pendingOrdersJson)
        : [];

    final orderId = pendingOrders.length + 1;

    // Calculate enhanced pricing data
    final subtotal = cartItems.fold(
      0.0,
      (sum, item) => sum + item.baseSubtotal,
    );
    final itemDiscounts = cartItems.fold(
      0.0,
      (sum, item) => sum + item.discountAmount,
    );

    // Extract cart-level discounts from additionalData
    final cartDiscount = additionalData?['cartData']?['cartDiscount'] ?? 0.0;
    final cartDiscountPercent =
        additionalData?['cartData']?['cartDiscountPercent'] ?? 0.0;
    final cartDiscountAmount =
        cartDiscount + (subtotal * cartDiscountPercent / 100);

    final totalDiscount = itemDiscounts + cartDiscountAmount;
    final taxableAmount = subtotal - totalDiscount;

    // Extract tax rate from additionalData or use default
    final taxRate = additionalData?['cartData']?['taxRate'] ?? 0.0;
    final taxAmount = taxableAmount * taxRate / 100;

    // Extract additional charges
    final additionalDiscount = additionalData?['additionalDiscount'] ?? 0.0;
    final shippingAmount = additionalData?['shippingAmount'] ?? 0.0;
    final tipAmount = additionalData?['tipAmount'] ?? 0.0;

    final finalTotal =
        taxableAmount +
        taxAmount +
        shippingAmount +
        tipAmount -
        additionalDiscount;

    final orderData = {
      'id': orderId,
      'order_data': {
        'line_items': cartItems
            .map(
              (item) => {
                'product_id': item.product.id,
                'product_name': item.product.name,
                'product_sku': item.product.sku,
                'quantity': item.quantity,
                'price': item.product.price,
                'base_price': item.product.price, // Original price
                'manual_discount': item.manualDiscount,
                'manual_discount_percent': item.manualDiscountPercent,
                'discount_amount': item.discountAmount,
                'base_subtotal': item.baseSubtotal,
                'final_subtotal': item.subtotal,
                'has_manual_discount': item.hasManualDiscount,
              },
            )
            .toList(),
        'pricing_breakdown': {
          'subtotal': subtotal,
          'item_discounts': itemDiscounts,
          'cart_discount': cartDiscount,
          'cart_discount_percent': cartDiscountPercent,
          'cart_discount_amount': cartDiscountAmount,
          'additional_discount': additionalDiscount,
          'total_discount': totalDiscount + additionalDiscount,
          'taxable_amount': taxableAmount - additionalDiscount,
          'tax_rate': taxRate,
          'tax_amount': taxAmount,
          'shipping_amount': shippingAmount,
          'tip_amount': tipAmount,
          'final_total': finalTotal,
        },
        'total': finalTotal, // Use the calculated final total
        'original_total': subtotal, // Original total without any discounts
      },
      'customer_data': customerSelection.hasCustomer
          ? {
              'customerId': customerSelection.customer!.id,
              'firstName': customerSelection.customer!.firstName,
              'lastName': customerSelection.customer!.lastName,
              'email': customerSelection.customer!.email,
              'phone': customerSelection.customer!.phone,
              'company': customerSelection.customer!.company,
            }
          : null,
      'payment_data': {
        'method': additionalData?['paymentMethod'] ?? 'cash',
        'amount_paid': finalTotal,
        'status': 'completed',
      },
      'discount_summary': {
        'applied_discounts': cartItems
            .where((item) => item.hasManualDiscount)
            .map(
              (item) => {
                'product_id': item.product.id,
                'product_name': item.product.name,
                'discount_type': item.manualDiscount != null
                    ? 'amount'
                    : 'percent',
                'discount_value':
                    item.manualDiscount ?? item.manualDiscountPercent,
                'discount_amount': item.discountAmount,
              },
            )
            .toList(),
        'cart_level_discount': {
          'type': cartDiscount > 0 ? 'amount' : 'percent',
          'value': cartDiscount > 0 ? cartDiscount : cartDiscountPercent,
          'amount': cartDiscountAmount,
        },
        'additional_discount': additionalDiscount,
      },
      'settings_used': {
        'tax_rate': taxRate,
        'default_discount_rate':
            additionalData?['invoiceSettings']?['discountRate'] ?? 0.0,
        'business_info_used': additionalData?['businessInfo'] != null,
      },
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'sync_attempts': 0,
      'version': '2.0', // Version to identify enhanced order format
    };

    // Add additional data if provided
    if (additionalData != null) {
      orderData['additional_data'] = additionalData;
    }

    pendingOrders.add(orderData);
    await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));

    print(
      'Saved enhanced pending order #$orderId with total: ${Constants.CURRENCY_NAME}$finalTotal',
    );

    return orderId;
  } // Product operations

  // In LocalDatabase class - REPLACE the saveProducts method
  Future<void> saveProducts(List<Product> products) async {
    final prefs = await _prefs;

    // Get existing products first
    final existingProductsJson = prefs.getString(_productsKey);
    final Map<String, Product> existingProductsMap = {};

    if (existingProductsJson != null) {
      try {
        final List<dynamic> existingJsonList = json.decode(
          existingProductsJson,
        );
        for (var json in existingJsonList) {
          final id = json['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            existingProductsMap[id] = Product.fromFirestore(json, id);
          }
        }
      } catch (e) {
        print('Error loading existing products for merge: $e');
      }
    }

    // Merge new products with existing ones
    for (final product in products) {
      existingProductsMap[product.id] = product;
    }

    // Convert back to list and save
    final mergedProducts = existingProductsMap.values.toList();
    final productsJson = mergedProducts.map((p) {
      final data = p.toFirestore();
      data['id'] = p.id;
      return data;
    }).toList();

    await prefs.setString(_productsKey, json.encode(productsJson));
    await prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // In LocalDatabase class - ADD this method
  Future<List<Product>> getAllProducts() async {
    final prefs = await _prefs;
    final productsJson = prefs.getString(_productsKey);

    if (productsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(productsJson);
      return jsonList.map((json) {
        final id = json['id']?.toString() ?? '';
        return Product.fromFirestore(json, id);
      }).toList();
    } catch (e) {
      print('Error loading all cached products: $e');
      return [];
    }
  }

  Future<List<Product>> getProducts({
    int limit = 50,
    int offset = 0,
    String searchQuery = '',
    bool inStockOnly = false,
    double minPrice = 0,
    double maxPrice = double.infinity,
  }) async {
    final prefs = await _prefs;
    final productsJson = prefs.getString(_productsKey);

    if (productsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(productsJson);
      var products = jsonList.map((json) {
        final id = json['id']?.toString() ?? '';
        return Product.fromFirestore(json, id);
      }).toList();

      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        products = products
            .where(
              (product) =>
                  product.name.toLowerCase().contains(lowerQuery) ||
                  (product.sku.toLowerCase().contains(lowerQuery)),
            )
            .toList();
      }

      if (inStockOnly) {
        products = products.where((product) => product.inStock).toList();
      }

      if (minPrice > 0) {
        products = products
            .where((product) => product.price >= minPrice)
            .toList();
      }

      if (maxPrice < double.infinity) {
        products = products
            .where((product) => product.price <= maxPrice)
            .toList();
      }

      products.sort((a, b) => a.name.compareTo(b.name));
      final start = offset;
      final end = (offset + limit) > products.length
          ? products.length
          : (offset + limit);

      return products.sublist(start, end);
    } catch (e) {
      print('Error loading cached products: $e');
      return [];
    }
  }

  Future<Product?> getProductById(String id) async {
    final products = await getProducts();
    try {
      return products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<Product?> getProductBySku(String sku) async {
    final products = await getProducts();
    try {
      return products.firstWhere((product) => product.sku == sku);
    } catch (e) {
      return null;
    }
  }

  // Cart operations
  Future<void> saveCartItems(List<CartItem> items) async {
    final prefs = await _prefs;
    final cartJson = items.map((item) {
      final productData = item.product.toFirestore();
      productData['id'] = item.product.id;
      return {'product': productData, 'quantity': item.quantity};
    }).toList();
    await prefs.setString(_cartKey, json.encode(cartJson));
  }

  Future<List<CartItem>> getCartItems() async {
    final prefs = await _prefs;
    final cartJson = prefs.getString(_cartKey);

    if (cartJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(cartJson);
      return jsonList.map((json) {
        final productData = json['product'] as Map<String, dynamic>;
        final productId = productData['id']?.toString() ?? '';
        final product = Product.fromFirestore(productData, productId);
        return CartItem(product: product, quantity: json['quantity']);
      }).toList();
    } catch (e) {
      print('Error loading cart: $e');
      return [];
    }
  }

  Future<void> clearCart() async {
    final prefs = await _prefs;
    await prefs.remove(_cartKey);
  }

  // Pending orders operations
  Future<int> savePendingOrder(List<CartItem> cartItems) async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);
    final List<dynamic> pendingOrders = pendingOrdersJson != null
        ? json.decode(pendingOrdersJson)
        : [];

    final orderId = pendingOrders.length + 1;

    final orderData = {
      'id': orderId,
      'order_data': {
        'line_items': cartItems
            .map(
              (item) => {
                'product_id': item.product.id,
                'product_name': item.product.name,
                'product_sku': item.product.sku,
                'quantity': item.quantity,
                'price': item.product.price,
              },
            )
            .toList(),
        'total': cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
      },
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'sync_attempts': 0,
    };

    pendingOrders.add(orderData);
    await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));

    return orderId;
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);

    if (pendingOrdersJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(pendingOrdersJson);
      return jsonList
          .where((order) => order['sync_status'] == 'pending')
          .map((order) => Map<String, dynamic>.from(order))
          .toList();
    } catch (e) {
      print('Error loading pending orders: $e');
      return [];
    }
  }

  Future<void> updatePendingOrderStatus(
    int orderId,
    String status, {
    int attempts = 0,
  }) async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);

    if (pendingOrdersJson == null) return;

    try {
      final List<dynamic> pendingOrders = json.decode(pendingOrdersJson);
      for (var i = 0; i < pendingOrders.length; i++) {
        if (pendingOrders[i]['id'] == orderId) {
          pendingOrders[i]['sync_status'] = status;
          pendingOrders[i]['sync_attempts'] = attempts;
          pendingOrders[i]['last_sync_attempt'] = DateTime.now()
              .toIso8601String();
          break;
        }
      }
      await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));
    } catch (e) {
      print('Error updating pending order: $e');
    }
  }

  Future<void> deletePendingOrder(int orderId) async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);

    if (pendingOrdersJson == null) return;

    try {
      final List<dynamic> pendingOrders = json.decode(pendingOrdersJson);
      pendingOrders.removeWhere((order) => order['id'] == orderId);
      await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));
    } catch (e) {
      print('Error deleting pending order: $e');
    }
  }

  // Pending restocks operations
  Future<int> savePendingRestock(
    String productId,
    int quantity,
    String? barcode,
  ) async {
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);
    final List<dynamic> pendingRestocks = pendingRestocksJson != null
        ? json.decode(pendingRestocksJson)
        : [];

    final restockId = pendingRestocks.length + 1;

    final restockData = {
      'id': restockId,
      'productId': productId,
      'quantity': quantity,
      'barcode': barcode,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'sync_attempts': 0,
    };

    pendingRestocks.add(restockData);
    await prefs.setString(_pendingRestocksKey, json.encode(pendingRestocks));

    return restockId;
  }

  Future<List<Map<String, dynamic>>> getPendingRestocks() async {
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);

    if (pendingRestocksJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(pendingRestocksJson);
      return jsonList
          .where((restock) => restock['sync_status'] == 'pending')
          .map((restock) => Map<String, dynamic>.from(restock))
          .toList();
    } catch (e) {
      print('Error loading pending restocks: $e');
      return [];
    }
  }

  Future<void> updatePendingRestockStatus(
    int restockId,
    String status, {
    int attempts = 0,
  }) async {
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);

    if (pendingRestocksJson == null) return;

    try {
      final List<dynamic> pendingRestocks = json.decode(pendingRestocksJson);
      for (var i = 0; i < pendingRestocks.length; i++) {
        if (pendingRestocks[i]['id'] == restockId) {
          pendingRestocks[i]['sync_status'] = status;
          pendingRestocks[i]['sync_attempts'] = attempts;
          pendingRestocks[i]['last_sync_attempt'] = DateTime.now()
              .toIso8601String();
          break;
        }
      }
      await prefs.setString(_pendingRestocksKey, json.encode(pendingRestocks));
    } catch (e) {
      print('Error updating pending restock: $e');
    }
  }

  Future<void> deletePendingRestock(int restockId) async {
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);

    if (pendingRestocksJson == null) return;

    try {
      final List<dynamic> pendingRestocks = json.decode(pendingRestocksJson);
      pendingRestocks.removeWhere((restock) => restock['id'] == restockId);
      await prefs.setString(_pendingRestocksKey, json.encode(pendingRestocks));
    } catch (e) {
      print('Error deleting pending restock: $e');
    }
  }
}
// dashboard_offline_models.dart
class OfflineDashboardData {
  final DashboardStats stats;
  final List<Order> recentOrders;
  final List<Product> lowStockProducts;
  final List<RevenueDataPoint> revenueData;
  final List<TopSellingProduct> topSellingProducts;
  final List<Customer> recentCustomers;
  final DateTime lastUpdated;
  final String tenantId;

  OfflineDashboardData({
    required this.stats,
    required this.recentOrders,
    required this.lowStockProducts,
    required this.revenueData,
    required this.topSellingProducts,
    required this.recentCustomers,
    required this.lastUpdated,
    required this.tenantId,
  });

  Map<String, dynamic> toJson() {
    return {
      'stats': {
        'totalRevenue': stats.totalRevenue,
        'todayRevenue': stats.todayRevenue,
        'totalSales': stats.totalSales,
        'todaySales': stats.todaySales,
        'totalProducts': stats.totalProducts,
        'lowStockProducts': stats.lowStockProducts,
        'totalCustomers': stats.totalCustomers,
        'todayCustomers': stats.todayCustomers,
        'averageOrderValue': stats.averageOrderValue,
        'conversionRate': stats.conversionRate,
        'revenueGrowth': stats.revenueGrowth,
        'salesGrowth': stats.salesGrowth,
        'todayReturns': stats.todayReturns,
        'totalReturns': stats.totalReturns,
      },
      // 'recentOrders': recentOrders.map((order) => order.toFirestore()).toList(),
      'lowStockProducts': lowStockProducts.map((product) => product.toFirestore()).toList(),
      'revenueData': revenueData.map((point) => {
        'date': point.date.toIso8601String(),
        'revenue': point.revenue,
        'orders': point.orders,
      }).toList(),
      'topSellingProducts': topSellingProducts.map((product) => {
        'productId': product.productId,
        'productName': product.productName,
        'totalSold': product.totalSold,
        'totalRevenue': product.totalRevenue,
        'imageUrl': product.imageUrl,
      }).toList(),
      'recentCustomers': recentCustomers.map((customer) => customer.toFirestore()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'tenantId': tenantId,
    };
  }

  factory OfflineDashboardData.fromJson(Map<String, dynamic> json) {
    return OfflineDashboardData(
      stats: DashboardStats(
        totalRevenue: json['stats']['totalRevenue'] ?? 0.0,
        todayRevenue: json['stats']['todayRevenue'] ?? 0.0,
        totalSales: json['stats']['totalSales'] ?? 0,
        todaySales: json['stats']['todaySales'] ?? 0,
        totalProducts: json['stats']['totalProducts'] ?? 0,
        lowStockProducts: json['stats']['lowStockProducts'] ?? 0,
        totalCustomers: json['stats']['totalCustomers'] ?? 0,
        todayCustomers: json['stats']['todayCustomers'] ?? 0,
        averageOrderValue: json['stats']['averageOrderValue'] ?? 0.0,
        conversionRate: json['stats']['conversionRate'] ?? 0.0,
        revenueGrowth: json['stats']['revenueGrowth'] ?? 0.0,
        salesGrowth: json['stats']['salesGrowth'] ?? 0.0,
        todayReturns: json['stats']['todayReturns'] ?? 0,
        totalReturns: json['stats']['totalReturns'] ?? 0,
      ),
      recentOrders: (json['recentOrders'] as List<dynamic>).map((orderJson) {
        return Order.fromFirestore(Map<String, dynamic>.from(orderJson), '');
      }).toList(),
      lowStockProducts: (json['lowStockProducts'] as List<dynamic>).map((productJson) {
        final id = productJson['id']?.toString() ?? '';
        return Product.fromFirestore(Map<String, dynamic>.from(productJson), id);
      }).toList(),
      revenueData: (json['revenueData'] as List<dynamic>).map((pointJson) {
        return RevenueDataPoint(
          date: DateTime.parse(pointJson['date']),
          revenue: pointJson['revenue'] ?? 0.0,
          orders: pointJson['orders'] ?? 0,
        );
      }).toList(),
      topSellingProducts: (json['topSellingProducts'] as List<dynamic>).map((productJson) {
        return TopSellingProduct(
          productId: productJson['productId'] ?? '',
          productName: productJson['productName'] ?? '',
          totalSold: productJson['totalSold'] ?? 0,
          totalRevenue: productJson['totalRevenue'] ?? 0.0,
          imageUrl: productJson['imageUrl'],
        );
      }).toList(),
      recentCustomers: (json['recentCustomers'] as List<dynamic>).map((customerJson) {
        final id = customerJson['id']?.toString() ?? '';
        return Customer.fromFirestore(Map<String, dynamic>.from(customerJson), id);
      }).toList(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      tenantId: json['tenantId'] ?? '',
    );
  }
}
// Enhanced Cart Manager
class EnhancedCartManager {
  final List<CartItem> _items = [];
  final StreamController<List<CartItem>> _cartController =
      StreamController<List<CartItem>>.broadcast();
  final StreamController<int> _itemCountController =
      StreamController<int>.broadcast();
  final StreamController<double> _totalController =
      StreamController<double>.broadcast();
  final LocalDatabase _localDb = LocalDatabase();
  bool _isInitialized = false;

  // Cart-level discounts
  double _cartDiscount = 0.0;
  double _cartDiscountPercent = 0.0;
  double _taxRate = 0.0;

  Stream<List<CartItem>> get cartStream => _cartController.stream;
  Stream<int> get itemCountStream => _itemCountController.stream;
  Stream<double> get totalStream => _totalController.stream;

  List<CartItem> get items => List.unmodifiable(_items);

  // Getters for discounts
  double get cartDiscount => _cartDiscount;
  double get cartDiscountPercent => _cartDiscountPercent;
  double get taxRate => _taxRate;

  // Enhanced total calculations
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.baseSubtotal);
  }

  double get totalDiscount {
    final itemDiscounts = _items.fold(
      0.0,
      (sum, item) => sum + item.discountAmount,
    );
    final cartDiscountAmount =
        _cartDiscount + (subtotal * _cartDiscountPercent / 100);
    return itemDiscounts + cartDiscountAmount;
  }

  double get taxableAmount {
    return subtotal - totalDiscount;
  }

  double get taxAmount {
    return taxableAmount * _taxRate / 100;
  }

  double get totalAmount {
    return taxableAmount + taxAmount;
  }

  // Load settings when initializing
  Future<void> initialize() async {
    if (_isInitialized) return;

    final savedCartItems = await _localDb.getCartItems();
    _items.clear();
    _items.addAll(savedCartItems);

    // Load tax rate from settings
    await _loadTaxRate();

    _notifyListeners();
    _isInitialized = true;
  }

  Future<void> _loadTaxRate() async {
    final prefs = await SharedPreferences.getInstance();
    _taxRate = prefs.getDouble('tax_rate') ?? 0.0;
  }

  // Enhanced add to cart with settings integration
  Future<void> addToCart(Product product) async {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity < product.stockQuantity) {
        _items[existingIndex].quantity++;
        await _localDb.saveCartItems(_items);
      } else {
        throw Exception(
          'Not enough stock available. Only ${product.stockQuantity} left.',
        );
      }
    } else {
      if (product.inStock && product.stockQuantity > 0) {
        final newItem = CartItem(product: product, quantity: 1);
        _items.add(newItem);
        await _localDb.saveCartItems(_items);
      } else {
        throw Exception('Product "${product.name}" is out of stock.');
      }
    }
    _notifyListeners();
  }

  // Apply manual discount to specific item
  Future<void> applyItemDiscount(
    String productId, {
    double? discountAmount,
    double? discountPercent,
  }) async {
    final itemIndex = _items.indexWhere((item) => item.product.id == productId);
    if (itemIndex >= 0) {
      _items[itemIndex].manualDiscount = discountAmount;
      _items[itemIndex].manualDiscountPercent = discountPercent;
      await _localDb.saveCartItems(_items);
      _notifyListeners();
    }
  }

  // Remove manual discount from specific item
  Future<void> removeItemDiscount(String productId) async {
    final itemIndex = _items.indexWhere((item) => item.product.id == productId);
    if (itemIndex >= 0) {
      _items[itemIndex].manualDiscount = null;
      _items[itemIndex].manualDiscountPercent = null;
      await _localDb.saveCartItems(_items);
      _notifyListeners();
    }
  }

  // Apply cart-level discount
  Future<void> applyCartDiscount({
    double? discountAmount,
    double? discountPercent,
  }) async {
    _cartDiscount = discountAmount ?? 0.0;
    _cartDiscountPercent = discountPercent ?? 0.0;
    _notifyListeners();
  }

  // Remove cart-level discount
  Future<void> removeCartDiscount() async {
    _cartDiscount = 0.0;
    _cartDiscountPercent = 0.0;
    _notifyListeners();
  }

  // Update tax rate
  Future<void> updateTaxRate(double newTaxRate) async {
    _taxRate = newTaxRate;
    _notifyListeners();
  }

  // Enhanced checkout items with discount information
  List<CartItem> getCheckoutItems() {
    return _items
        .map(
          (item) => CartItem(
            product: item.product,
            quantity: item.quantity,
            manualDiscount: item.manualDiscount,
            manualDiscountPercent: item.manualDiscountPercent,
          ),
        )
        .toList();
  }

  // Enhanced cart data for order creation
  Map<String, dynamic> getCartDataForOrder() {
    return {
      'items': _items
          .map(
            (item) => {
              'productId': item.product.id,
              'productName': item.product.name,
              'quantity': item.quantity,
              'price': item.product.price,
              'manualDiscount': item.manualDiscount,
              'manualDiscountPercent': item.manualDiscountPercent,
              'subtotal': item.subtotal,
              'baseSubtotal': item.baseSubtotal,
              'discountAmount': item.discountAmount,
            },
          )
          .toList(),
      'subtotal': subtotal,
      'totalDiscount': totalDiscount,
      'taxableAmount': taxableAmount,
      'taxRate': _taxRate,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'cartDiscount': _cartDiscount,
      'cartDiscountPercent': _cartDiscountPercent,
    };
  }

  void _notifyListeners() {
    if (!_cartController.isClosed) {
      _cartController.add(List.from(_items));
    }
    if (!_itemCountController.isClosed) {
      _itemCountController.add(_items.length);
    }
    if (!_totalController.isClosed) {
      _totalController.add(totalAmount);
    }
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(productId);
      return;
    }

    final itemIndex = _items.indexWhere((item) => item.product.id == productId);
    if (itemIndex >= 0) {
      final product = _items[itemIndex].product;
      if (newQuantity <= product.stockQuantity) {
        _items[itemIndex].quantity = newQuantity;
        await _localDb.saveCartItems(_items);
        _notifyListeners();
      } else {
        throw Exception(
          'Only ${product.stockQuantity} items of "${product.name}" in stock.',
        );
      }
    }
  }

  Future<void> removeFromCart(String productId) async {
    _items.removeWhere((item) => item.product.id == productId);
    await _localDb.saveCartItems(_items);
    _notifyListeners();
  }

  Future<void> clearCart() async {
    _items.clear();
    await _localDb.clearCart();
    _notifyListeners();
  }

  void dispose() {
    _cartController.close();
    _itemCountController.close();
  }
}

// Main Application
class POSApp extends StatefulWidget {
  const POSApp({super.key});

  @override
  State<POSApp> createState() => _POSAppState();
}

class _POSAppState extends State<POSApp> {
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    setState(() {});
  }

  final EnhancedPOSService _posService = EnhancedPOSService();

  Future<bool> _onWillPop(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit the POS?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${Constants.TANENT_NAME} POS - Offline',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PopScope(
        canPop: false, // Prevents back button entirely
        onPopInvoked: (didPop) async {
          if (!didPop) {
            final shouldPop = await _onWillPop(context);
            if (shouldPop && context.mounted) {
              // If you want to actually close the app
              SystemNavigator.pop();
            }
          }
        },
        child: MainPOSScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}


// Modern Dashboard Screen

// Supporting Models

class ChartData {
  final String day;
  final double revenue;

  ChartData(this.day, this.revenue);
}

// Main POS Screen
class MainPOSScreen extends StatefulWidget {
  const MainPOSScreen({super.key});

  @override
  _MainPOSScreenState createState() => _MainPOSScreenState();
}

class _MainPOSScreenState extends State<MainPOSScreen> {
  int _currentIndex = 0;
  final EnhancedCartManager _cartManager = EnhancedCartManager();
  final EnhancedPOSService _posService = EnhancedPOSService();
  bool _isTestingConnection = false;
  String _connectionStatus = '';
  bool _isOnline = false;
  int _cartItemCount = 0;
  final LocalDatabase _localDb = LocalDatabase();
  final _firestore = FirestoreService();
  final List<Widget> _clientAdminScreens = [];
  final List<Widget> _clientSalesManagerScreens = [];
  final List<Widget> _clientCashierScreens = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final tenantId = authProvider.currentUser?.tenantId;

    if (tenantId != null && tenantId != 'super_admin') {
      _posService.setTenantContext(tenantId);
      print('Tenant context set: $tenantId'); // Add this for debugging
    }

    _posService.initialize();
    await _cartManager.initialize();

    // Listen to cart item count changes
    _cartManager.itemCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _cartItemCount = count;
        });
      }
    });

    _posService.onlineStatusStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _connectionStatus = isOnline
              ? 'Online - Connected'
              : 'Offline - Working Locally';
        });
      }
    });

    await _testConnection();

    _clientAdminScreens.addAll([
      ModernDashboardScreen(),

      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),
      AnalyticsDashboardScreen(),
      ProductManagementScreen(),

      ReturnsManagementScreen(), // Add this line

      SettingsScreen(),
      EnhancedUsersScreen(),
      ClientTicketsScreen(),

      ProfileScreen(),
    ]);
    setState(() {});

    _clientSalesManagerScreens.addAll([
      ModernDashboardScreen(),

      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),
      // AnalyticsDashboardScreen(),
      ProductManagementScreen(),

      ReturnsManagementScreen(), // Add this line
      // SettingsScreen(),
      // UsersScreen(),
      ClientTicketsScreen(),

      ProfileScreen(),
    ]);
    setState(() {});
    _clientCashierScreens.addAll([
      ModernDashboardScreen(),

      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),

      // AnalyticsDashboardScreen(),
      // ProductManagementScreen(),
      ReturnsManagementScreen(), // Add this line
      // SettingsScreen(),
      // UsersScreen(),
      ClientTicketsScreen(),

      ProfileScreen(),
    ]);
    setState(() {});
  }

  // Customer management methods
  Future<List<Customer>> searchCustomers(String query) async {
    return await _firestore.searchCustomers(query);
  }

  Future<Customer?> getCustomerById(String id) async {
    return await _firestore.getCustomerById(id);
  }

  Future<Customer?> getCustomerByEmail(String email) async {
    return await _firestore.getCustomerByEmail(email);
  }

  Future<String> addCustomer(Customer customer) async {
    return await _firestore.addCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _firestore.updateCustomer(customer);
  }

  // Enhanced order creation
  Future<OrderCreationResult> createOrderWithCustomer(
    List<CartItem> cartItems,
    CustomerSelection customerSelection,
  ) async {
    if (_isOnline) {
      try {
        final order = await _firestore.createOrderWithCustomer(
          cartItems,
          customerSelection,
        );
        return OrderCreationResult.success(order);
      } catch (e) {
        print('Online order creation failed, saving locally: $e');
        return await _createOfflineOrderWithCustomer(
          cartItems,
          customerSelection,
        );
      }
    } else {
      return await _createOfflineOrderWithCustomer(
        cartItems,
        customerSelection,
      );
    }
  }

  Future<OrderCreationResult> _createOfflineOrderWithCustomer(
    List<CartItem> cartItems,
    CustomerSelection customerSelection,
  ) async {
    try {
      // Update local stock quantities
      for (final item in cartItems) {
        await _updateLocalProductStock(item.product.id, -item.quantity);
      }

      final pendingOrderId = await _localDb.savePendingOrderWithCustomer(
        cartItems,
        customerSelection,
      );
      await _localDb.clearCart();
      return OrderCreationResult.offline(pendingOrderId);
    } catch (e) {
      return OrderCreationResult.error('Failed to save order locally: $e');
    }
  }

  // In EnhancedPOSService class - ENHANCE the _updateLocalProductStock method
  Future<void> _updateLocalProductStock(String productId, int quantity) async {
    final products = await _localDb.getProducts(limit: 0); // Get all products
    final productIndex = products.indexWhere((p) => p.id == productId);

    if (productIndex != -1) {
      final product = products[productIndex];
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        sku: product.sku,
        price: product.price,
        regularPrice: product.regularPrice,
        salePrice: product.salePrice,
        imageUrl: product.imageUrl,
        imageUrls: product.imageUrls,
        stockQuantity: product.stockQuantity + quantity,
        inStock: (product.stockQuantity + quantity) > 0,
        stockStatus: (product.stockQuantity + quantity) > 0
            ? 'instock'
            : 'outofstock',
        description: product.description,
        shortDescription: product.shortDescription,
        categories: product.categories,
        attributes: product.attributes,
        metaData: product.metaData,
        dateCreated: product.dateCreated,
        dateModified: DateTime.now(),
        purchasable: product.purchasable,
        type: product.type,
        status: product.status,
        featured: product.featured,
        permalink: product.permalink,
        averageRating: product.averageRating,
        ratingCount: product.ratingCount,
        parentId: product.parentId,
        variations: product.variations,
        weight: product.weight,
        dimensions: product.dimensions,
      );

      // Save only the updated product - the saveProducts method will now merge it
      await _localDb.saveProducts([updatedProduct]);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      final success = await _posService.testConnection();
      setState(() {
        _connectionStatus = success
            ? 'Online - Connected'
            : 'Offline - Working Locally';
        _isOnline = success;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Offline - ${e.toString()}';
        _isOnline = false;
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _manualSync() async {
    if (_isOnline) {
      setState(() {
        _isTestingConnection = true;
        _connectionStatus = 'Syncing...';
      });

      await _posService.manualSync();

      setState(() {
        _isTestingConnection = false;
        _connectionStatus = 'Sync completed';
      });

      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _connectionStatus = _isOnline
                ? 'Online - Connected'
                : 'Offline - Working Locally';
          });
        }
      });
    }
  }

  final GlobalKey<LiquidPullToRefreshState> _refreshIndicatorKey =
      GlobalKey<LiquidPullToRefreshState>();
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _manualSync(); // Your existing sync method
    setState(() => _isRefreshing = false);
  }

  // Helper method to wrap screens with scrollability
  Widget _buildRefreshableScreen(Widget screen) {
    return LiquidPullToRefresh(
      key: _refreshIndicatorKey,
      onRefresh: _handleRefresh,
      color: Colors.blue[700]!,
      backgroundColor: Colors.white,
      height: 100,
      animSpeedFactor: 2,
      showChildOpacityTransition: false,
      child: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(), // Important!
        slivers: [SliverFillRemaining(hasScrollBody: false, child: screen)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryManagementScreen(),
                ),
              );
            },
            child: Text("Category"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceSettingsScreen(),
                ),
              );
            },
            child: Text("Print"),
          ),
          if (_isTestingConnection)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (_isOnline)
            IconButton(
              icon: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: _isRefreshing
                      ? LinearGradient(colors: [Colors.purple, Colors.blue])
                      : LinearGradient(
                          colors: [Colors.blue.shade400, Colors.cyan.shade400],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(_isRefreshing ? 0.8 : 0.4),
                      blurRadius: _isRefreshing ? 12 : 8,
                      spreadRadius: _isRefreshing ? 2 : 1,
                    ),
                  ],
                ),
                child: AnimatedRotation(
                  duration: Duration(milliseconds: 500),
                  turns: _isRefreshing ? 1 : 0,
                  child: Icon(
                    _isRefreshing ? Icons.downloading : Icons.sync,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              onPressed: _isRefreshing ? null : _handleRefresh,
              tooltip: 'Smart Sync',
            )
          else
            IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[400],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off, color: Colors.white, size: 20),
              ),
              onPressed: _testConnection,
              tooltip: 'Check Connection',
            ),
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SalesManagementScreen(),
                ),
              );
            },
          ),
          if (authProvider.currentUser!.canManageUsers)
            IconButton(
              icon: Icon(Icons.people),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnhancedUsersScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedProfileScreen(),
                ),
              );
            },
          ),
        ],
        flexibleSpace: Container(),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${Constants.TANENT_NAME} POS'),
            if (_connectionStatus.isNotEmpty)
              Text(
                _connectionStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: _isOnline ? Colors.green[200] : Colors.orange[200],
                ),
              ),
          ],
        ),
        backgroundColor: _isOnline ? Colors.blue[700] : Colors.orange[700],
        elevation: 0,
      ),
      body: _clientAdminScreens.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _isOnline
          ? _buildRefreshableScreen(_clientAdminScreens[_currentIndex])
          : _clientAdminScreens[_currentIndex],
      bottomNavigationBar: authProvider.currentUser!.canManageProducts
          ? BottomNavigationBar(
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex < 5
                  ? _currentIndex
                  : 4, // Ensure index is within bounds
              onTap: (index) {
                if (index == 4) {
                  // More option
                  _showMoreMenu(context, authProvider);
                } else {
                  setState(() => _currentIndex = index);
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_bag_outlined),
                  activeIcon: Icon(Icons.shopping_bag),
                  label: 'Products',
                ),
                BottomNavigationBarItem(
                  icon: _buildCartIcon(),
                  activeIcon: _buildCartIcon(isActive: true),
                  label: 'Cart',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined),
                  activeIcon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz),
                  activeIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            )
          : authProvider.currentUser!.canManageUsers
          ? BottomNavigationBar(
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex < 5
                  ? _currentIndex
                  : 4, // Ensure index is within bounds
              onTap: (index) {
                if (index == 4) {
                  // More option
                  _showMoreMenu(context, authProvider);
                } else {
                  setState(() => _currentIndex = index);
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_bag_outlined),
                  activeIcon: Icon(Icons.shopping_bag),
                  label: 'Products',
                ),
                BottomNavigationBarItem(
                  icon: _buildCartIcon(),
                  activeIcon: _buildCartIcon(isActive: true),
                  label: 'Cart',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined),
                  activeIcon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz),
                  activeIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            )
          : BottomNavigationBar(
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex < 5
                  ? _currentIndex
                  : 3, // Ensure index is within bounds
              onTap: (index) {
                if (index == 3) {
                  // More option
                  _showMoreMenu(context, authProvider);
                } else {
                  setState(() => _currentIndex = index);
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_bag_outlined),
                  activeIcon: Icon(Icons.shopping_bag),
                  label: 'Products',
                ),
                BottomNavigationBarItem(
                  icon: _buildCartIcon(),
                  activeIcon: _buildCartIcon(isActive: true),
                  label: 'Cart',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz),
                  activeIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
    );
  }

  // Helper method for cart icon with badge
  Widget _buildCartIcon({bool isActive = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined),
        if (_cartItemCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                '$_cartItemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // More menu dialog
  void _showMoreMenu(BuildContext context, MyAuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (authProvider.currentUser!.canManageProducts ||
                  authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Manage Inventory'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(
                      () => _currentIndex =
                          authProvider.currentUser!.canManageUsers ? 4 : 3,
                    );

                    // Navigate to manage screen
                  },
                ),
              ListTile(
                leading: Icon(Icons.assignment_return_outlined),
                title: Text('Returns'),
                onTap: () {
                  Navigator.pop(context);
                  setState(
                    () => _currentIndex =
                        authProvider.currentUser!.canManageUsers ? 5 : 4,
                  );

                  // Navigate to returns screen
                },
              ),
              if (authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(
                      () => _currentIndex =
                          authProvider.currentUser!.canManageUsers ? 6 : 5,
                    );

                    // Navigate to settings screen
                  },
                ),
              if (authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Users'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(
                      () => _currentIndex =
                          authProvider.currentUser!.canManageUsers ? 7 : 6,
                    );

                    // Navigate to users screen
                  },
                ),
              ListTile(
                leading: Icon(Icons.report_problem),
                title: Text('Ticket'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 8);

                  // Navigate to profile screen
                },
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 9);

                  // Navigate to profile screen
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _posService.dispose();
    _cartManager.dispose();
    super.dispose();
  }
}

// Update your MainPOSScreen to include this new screen
// Add this to your _clientAdminScreens, _clientSalesManagerScreens, and _clientCashierScreens lists:
// Replace the existing products screen with this new one:

// In your MainPOSScreen build method, update the navigation:
// Change the products screen to use the new ProductSellingScreen:

// Example update in MainPOSScreen:
/*
_clientAdminScreens.addAll([
  DashboardHome(),
  ProductSellingScreen(cartManager: _cartManager), // REPLACE THIS LINE
  CartScreen(cartManager: _cartManager),
  AnalyticsDashboardScreen(),
  ProductManagementScreen(),
  ReturnsManagementScreen(),
  SettingsScreen(),
  UsersScreen(),
  TicketsScreen(),
  ProfileScreen(),
]);
*/

// Similarly update for _clientSalesManagerScreens and _clientCashierScreens
class HardwareScannerScreen extends StatefulWidget {
  const HardwareScannerScreen({super.key});

  @override
  _HardwareScannerScreenState createState() => _HardwareScannerScreenState();
}

class _HardwareScannerScreenState extends State<HardwareScannerScreen> {
  final FocusNode _focusNode = FocusNode();
  final StringBuffer _buffer = StringBuffer();
  Timer? _inputTimer;
  static const Duration _inputDelay = Duration(milliseconds: 300);
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _onKey(RawKeyEvent event) {
    if (_scanned || event is! RawKeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _finalizeScan();
    } else {
      final character = event.character;
      if (character != null && character.trim().isNotEmpty) {
        _buffer.write(character);
        _inputTimer?.cancel();
        _inputTimer = Timer(_inputDelay, _finalizeScan);
      }
    }
  }

  void _finalizeScan() {
    if (_scanned) return;
    _scanned = true;
    final scanned = _buffer.toString().trim();
    Navigator.of(context).pop(scanned);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _inputTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan with Hardware Device')),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _onKey,
        child: Center(
          child: Text(
            'Waiting for input from connected scanner...',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

// Enhanced CartScreen with discount support
class CartScreen extends StatefulWidget {
  final EnhancedCartManager cartManager;

  const CartScreen({super.key, required this.cartManager});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _currentCartItems = [];
  double _totalAmount = 0.0;
  double _subtotal = 0.0;
  double _discountAmount = 0.0;
  double _taxAmount = 0.0;
  double _taxRate = 0.0;

  @override
  void initState() {
    super.initState();
    _currentCartItems = List.from(widget.cartManager.items);
    _updateTotals();

    widget.cartManager.cartStream.listen((cartItems) {
      if (mounted) {
        setState(() {
          _currentCartItems = List.from(cartItems);
          _updateTotals();
        });
      }
    });

    widget.cartManager.totalStream.listen((total) {
      if (mounted) {
        setState(() {
          _totalAmount = total;
          _updateTotals();
        });
      }
    });
  }

  void _updateTotals() {
    _subtotal = widget.cartManager.subtotal;
    _discountAmount = widget.cartManager.totalDiscount;
    _taxAmount = widget.cartManager.taxAmount;
    _taxRate = widget.cartManager.taxRate;
    _totalAmount = widget.cartManager.totalAmount;
  }

  void _showManualDiscountDialog(CartItem item) {
    final discountAmountController = TextEditingController();
    final discountPercentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Discount to ${item.product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Original Price: ${Constants.CURRENCY_NAME}${item.product.price.toStringAsFixed(2)}',
            ),
            Text('Quantity: ${item.quantity}'),
            Text(
              'Subtotal: ${Constants.CURRENCY_NAME}${item.baseSubtotal.toStringAsFixed(2)}',
            ),
            SizedBox(height: 16),
            TextField(
              controller: discountAmountController,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountPercentController.clear();
                }
              },
            ),
            SizedBox(height: 8),
            Text('OR'),
            SizedBox(height: 8),
            TextField(
              controller: discountPercentController,
              decoration: InputDecoration(
                labelText: 'Discount Percentage (%)',
                suffixText: '%',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountAmountController.clear();
                }
              },
            ),
          ],
        ),
        actions: [

          if (item.hasManualDiscount)
            TextButton(
              onPressed: () {
                widget.cartManager.removeItemDiscount(item.product.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Discount removed from ${item.product.name}'),
                  ),
                );
              },
              child: Text(
                'Remove Discount',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final discountAmount = double.tryParse(
                discountAmountController.text,
              );
              final discountPercent = double.tryParse(
                discountPercentController.text,
              );

              if (discountAmount != null || discountPercent != null) {
                widget.cartManager.applyItemDiscount(
                  item.product.id,
                  discountAmount: discountAmount,
                  discountPercent: discountPercent,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Discount applied to ${item.product.name}'),
                  ),
                );
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  void _showCartDiscountDialog() {
    final discountAmountController = TextEditingController();
    final discountPercentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Cart Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cart Subtotal: ${Constants.CURRENCY_NAME}${_subtotal.toStringAsFixed(2)}',
            ),
            SizedBox(height: 16),
            TextField(
              controller: discountAmountController,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountPercentController.clear();
                }
              },
            ),
            SizedBox(height: 8),
            Text('OR'),
            SizedBox(height: 8),
            TextField(
              controller: discountPercentController,
              decoration: InputDecoration(
                labelText: 'Discount Percentage (%)',
                suffixText: '%',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountAmountController.clear();
                }
              },
            ),
          ],
        ),
        actions: [
          if (widget.cartManager.cartDiscount > 0 ||
              widget.cartManager.cartDiscountPercent > 0)
            TextButton(
              onPressed: () {
                widget.cartManager.removeCartDiscount();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cart discount removed')),
                );
              },
              child: Text(
                'Remove Discount',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final discountAmount = double.tryParse(
                discountAmountController.text,
              );
              final discountPercent = double.tryParse(
                discountPercentController.text,
              );

              if (discountAmount != null || discountPercent != null) {
                widget.cartManager.applyCartDiscount(
                  discountAmount: discountAmount,
                  discountPercent: discountPercent,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cart discount applied')),
                );
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _currentCartItems.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart'),
        actions: [
          if (!isEmpty)
            IconButton(
              icon: Icon(Icons.discount),
              onPressed: _showCartDiscountDialog,
              tooltip: 'Apply Cart Discount',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _currentCartItems.length,
                    itemBuilder: (context, index) {
                      final item = _currentCartItems[index];
                      return CartItemCard(
                        item: item,
                        onUpdateQuantity: (newQuantity) {
                          _updateItemQuantity(item.product.id, newQuantity);
                        },
                        onRemove: () {
                          _removeItem(item.product.id);
                        },
                        onApplyDiscount: () {
                          _showManualDiscountDialog(item);
                        },
                      );
                    },
                  ),
          ),
          _buildCheckoutSection(isEmpty),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text('Your cart is empty', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection(bool isEmpty) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Price Breakdown
          _buildPriceBreakdown(),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isEmpty ? null : _proceedToCheckout,
              child: Text(
                'PROCEED TO CHECKOUT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Column(
      children: [
        _buildPriceRow('Subtotal', _subtotal),
        if (_discountAmount > 0)
          _buildPriceRow('Discount', -_discountAmount, isDiscount: true),
        if (_taxRate > 0)
          _buildPriceRow('Tax (${_taxRate.toStringAsFixed(1)}%)', _taxAmount),
        Divider(),
        _buildPriceRow('TOTAL', _totalAmount, isTotal: true),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : Colors.black,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}${Constants.CURRENCY_NAME}${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.green
                  : (isTotal ? Colors.green[700] : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateItemQuantity(String productId, int newQuantity) async {
    try {
      await widget.cartManager.updateQuantity(productId, newQuantity);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  Future<void> _removeItem(String productId) async {
    await widget.cartManager.removeFromCart(productId);
    _showSnackBar('Item removed from cart', Colors.orange);
  }

  void _proceedToCheckout() {
    final checkoutItems = widget.cartManager.getCheckoutItems();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartManager: widget.cartManager,
          cartItems: checkoutItems,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

// Cart Item Card
// Cart Item Card

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final Function(int) onUpdateQuantity;
  final VoidCallback onRemove;
  final VoidCallback onApplyDiscount;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onUpdateQuantity,
    required this.onRemove,
    required this.onApplyDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: item.product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(item.product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${Constants.CURRENCY_NAME}${item.product.price.toStringAsFixed(2)} each',
                  ),
                  if (item.hasManualDiscount) ...[
                    SizedBox(height: 2),
                    Text(
                      'Discount: ${Constants.CURRENCY_NAME}${item.discountAmount.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuantityControls(),
                      Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.hasManualDiscount)
                            Text(
                              '${Constants.CURRENCY_NAME}${item.baseSubtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            '${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(width: 12),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'discount',
                            child: Row(
                              children: [
                                Icon(Icons.discount, size: 20),
                                SizedBox(width: 8),
                                Text('Apply Discount'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Remove',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'discount':
                              onApplyDiscount();
                              break;
                            case 'remove':
                              onRemove();
                              break;
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove, size: 18),
            onPressed: item.quantity > 1
                ? () => onUpdateQuantity(item.quantity - 1)
                : null,
            padding: EdgeInsets.zero,
          ),
          Text(
            item.quantity.toString(),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18),
            onPressed: () => onUpdateQuantity(item.quantity + 1),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
class OfflineInvoiceBottomSheet extends StatelessWidget {
  final int pendingOrderId;
  final Customer? customer;
  final Map<String, dynamic> businessInfo;
  final Map<String, dynamic> invoiceSettings;
  final double finalTotal;
  final String paymentMethod;

  const OfflineInvoiceBottomSheet({
    Key? key,
    required this.pendingOrderId,
    this.customer,
    required this.businessInfo,
    required this.invoiceSettings,
    required this.finalTotal,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Offline Order Saved',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text('Order ID: OFFLINE-$pendingOrderId'),
          SizedBox(height: 8),
          Text('Total: ${Constants.CURRENCY_NAME}${finalTotal.toStringAsFixed(2)}'),
          SizedBox(height: 8),
          Text('Payment: ${_getPaymentMethodName(paymentMethod)}'),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _printInvoice,
                  child: Text('Print Invoice'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'card': return 'Credit Card';
      case 'mobile_money': return 'Mobile Money';
      case 'credit': return 'Store Credit';
      default: return method;
    }
  }

  void _printInvoice() {
    // Implement offline invoice printing logic here
    // This could use a local printer service or generate a PDF
    print('Printing offline invoice for order: OFFLINE-$pendingOrderId');
  }
}

class CheckoutScreen extends StatefulWidget {
  final EnhancedCartManager cartManager;
  final List<CartItem> cartItems;

  const CheckoutScreen({
    super.key,
    required this.cartManager,
    required this.cartItems,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  bool _isProcessing = false;
  Order? _completedOrder;
  int? _pendingOrderId;
  String? _errorMessage;
  CustomerSelection _customerSelection = CustomerSelection(useDefault: true);

  // Settings data
  Map<String, dynamic> _invoiceSettings = {};
  Map<String, dynamic> _businessInfo = {};
  bool _isLoadingSettings = true;

  // Payment methods
  final List<String> _paymentMethods = [
    'cash',
    'card',
    'mobile_money',
    'credit',
  ];
  String _selectedPaymentMethod = 'cash';

  // Additional charges/discounts
  final TextEditingController _additionalDiscountController =
  TextEditingController();
  final TextEditingController _shippingController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();

  double _additionalDiscount = 0.0;
  double _shippingAmount = 0.0;
  double _tipAmount = 0.0;

  // Track if we should reset the screen
  bool _shouldResetScreen = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupCartListeners();
  }

  void _setupCartListeners() {
    widget.cartManager.totalStream.listen((total) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);

    try {
      final settings = await _posService.getInvoiceSettings();
      final businessInfo = await _posService.getBusinessInfo();

      if (mounted) {
        setState(() {
          _invoiceSettings = settings;
          _businessInfo = businessInfo;
          _isLoadingSettings = false;
        });

        // Apply default discount rate from settings if no manual discount is set
        final defaultDiscountRate = _invoiceSettings['discountRate'] ?? 0.0;
        if (defaultDiscountRate > 0 &&
            widget.cartManager.cartDiscountPercent == 0) {
          widget.cartManager.applyCartDiscount(
            discountPercent: defaultDiscountRate,
          );
        }

        // Apply tax rate from settings
        final taxRate = _invoiceSettings['taxRate'] ?? 0.0;
        widget.cartManager.updateTaxRate(taxRate);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSettings = false;
        });
      }
    }
  }

  void _showInvoiceOptions(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceOptionsBottomSheet(
        order: order,
        customer: _customerSelection.hasCustomer
            ? _customerSelection.customer
            : null,
        businessInfo: _businessInfo,
        invoiceSettings: _invoiceSettings,
      ),
    ).then((_) {
      // After invoice dialog is closed, reset the screen
      _resetCheckoutScreen();
    });
  }

  void _showOfflineInvoiceOptions(int pendingOrderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => OfflineInvoiceBottomSheet(
        pendingOrderId: pendingOrderId,
        customer: _customerSelection.hasCustomer
            ? _customerSelection.customer
            : null,
        businessInfo: _businessInfo,
        invoiceSettings: _invoiceSettings,
        finalTotal: _finalTotal,
        paymentMethod: _selectedPaymentMethod,
      ),
    ).then((_) {
      // After invoice dialog is closed, reset the screen
      _resetCheckoutScreen();
    });
  }

  Future<void> _selectCustomer() async {
    final result = await Navigator.push<CustomerSelection>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerSelectionScreen(
          posService: _posService,
          initialSelection: _customerSelection,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _customerSelection = result;
      });
    }
  }

  void _showAdditionalDiscountDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Additional Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current taxable amount: ${Constants.CURRENCY_NAME}${_taxableAmount.toStringAsFixed(2)}',
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          if (_additionalDiscount > 0)
            TextButton(
              onPressed: () {
                setState(() => _additionalDiscount = 0.0);
                _additionalDiscountController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Additional discount removed')),
                );
              },
              child: Text(
                'Remove Discount',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final discount = double.tryParse(controller.text);
              if (discount != null && discount > 0) {
                setState(() => _additionalDiscount = discount);
                _additionalDiscountController.text = discount.toStringAsFixed(
                  2,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Additional discount applied')),
                );
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  void _showShippingDialog() {
    final controller = TextEditingController(
      text: _shippingAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Shipping Amount'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Shipping Amount (${Constants.CURRENCY_NAME})',
            prefixText: Constants.CURRENCY_NAME,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final shipping = double.tryParse(controller.text) ?? 0.0;
              setState(() => _shippingAmount = shipping);
              _shippingController.text = shipping.toStringAsFixed(2);
              Navigator.pop(context);
            },
            child: Text('Apply Shipping'),
          ),
        ],
      ),
    );
  }

  void _showTipDialog() {
    final controller = TextEditingController(
      text: _tipAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tip Amount'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Tip Amount (${Constants.CURRENCY_NAME})',
            prefixText: Constants.CURRENCY_NAME,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final tip = double.tryParse(controller.text) ?? 0.0;
              setState(() => _tipAmount = tip);
              _tipController.text = tip.toStringAsFixed(2);
              Navigator.pop(context);
            },
            child: Text('Apply Tip'),
          ),
        ],
      ),
    );
  }

  // Enhanced total calculations with additional charges/discounts
  double get _subtotal => widget.cartManager.subtotal;
  double get _itemDiscounts => widget.cartManager.items.fold(
    0.0,
        (sum, item) => sum + item.discountAmount,
  );
  double get _cartDiscount =>
      widget.cartManager.cartDiscount +
          (_subtotal * widget.cartManager.cartDiscountPercent / 100);
  double get _totalDiscount =>
      _itemDiscounts + _cartDiscount + _additionalDiscount;
  double get _taxableAmount => _subtotal - _totalDiscount;
  double get _taxAmount => _taxableAmount * widget.cartManager.taxRate / 100;
  double get _finalTotal =>
      _taxableAmount + _taxAmount + _shippingAmount + _tipAmount;

  void _resetCheckoutScreen() {
    if (mounted) {
      setState(() {
        _additionalDiscount = 0.0;
        _shippingAmount = 0.0;
        _tipAmount = 0.0;
        _selectedPaymentMethod = 'cash';
        _customerSelection = CustomerSelection(useDefault: true);
        _completedOrder = null;
        _pendingOrderId = null;
        _errorMessage = null;

        // Clear controllers
        _additionalDiscountController.clear();
        _shippingController.clear();
        _tipController.clear();
      });
    }
  }

  Future<void> _processOrder() async {
    if (widget.cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cart is empty')));
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Create enhanced order data with all discount information
      final orderData = {
        'cartData': widget.cartManager.getCartDataForOrder(),
        'additionalDiscount': _additionalDiscount,
        'shippingAmount': _shippingAmount,
        'tipAmount': _tipAmount,
        'finalTotal': _finalTotal,
        'paymentMethod': _selectedPaymentMethod,
        'invoiceSettings': _invoiceSettings,
        'businessInfo': _businessInfo,
      };

      final result = await _posService.createOrderWithCustomer(
        widget.cartItems,
        _customerSelection,
        additionalData: orderData,
      );

      if (result.success) {
        // Clear cart first
        await widget.cartManager.clearCart();

        if (result.isOffline) {
          setState(() => _pendingOrderId = result.pendingOrderId);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order saved offline. Will sync when online.'),
              backgroundColor: Colors.orange,
            ),
          );

          // Show invoice for offline order
          if (result.pendingOrderId != null) {
            _showOfflineInvoiceOptions(result.pendingOrderId!);
          } else if (result.order != null) {
            _showInvoiceOptions(result.order!);
          } else {
            // If no order object but success, still show basic success and reset
            _resetCheckoutScreen();
          }
        } else {
          setState(() => _completedOrder = result.order);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order processed successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Show invoice for online order
          if (result.order != null) {
            _showInvoiceOptions(result.order!);
          } else {
            _resetCheckoutScreen();
          }
        }
      } else {
        setState(() => _errorMessage = result.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildCustomerSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: _selectCustomer, child: Text('Change')),
              ],
            ),
            SizedBox(height: 8),
            if (_customerSelection.hasCustomer)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _customerSelection.customer!.displayName,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(_customerSelection.customer!.email),
                  if (_customerSelection.customer!.phone.isNotEmpty)
                    Text(_customerSelection.customer!.phone),
                  if (_customerSelection.customer!.orderCount > 0)
                    Text(
                      '${_customerSelection.customer!.orderCount} previous orders',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Walk-in Customer (No customer information)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            widget.cartItems.isEmpty
                ? Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No items in cart',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) {
                final item = widget.cartItems[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.product.name,
                          style: TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Price Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildPriceRow('Subtotal', _subtotal),
            if (_itemDiscounts > 0)
              _buildPriceRow(
                'Item Discounts',
                -_itemDiscounts,
                isDiscount: true,
              ),
            if (_cartDiscount > 0)
              _buildPriceRow('Cart Discount', -_cartDiscount, isDiscount: true),
            if (_additionalDiscount > 0)
              _buildPriceRow(
                'Additional Discount',
                -_additionalDiscount,
                isDiscount: true,
              ),
            if (widget.cartManager.taxRate > 0)
              _buildPriceRow(
                'Tax (${widget.cartManager.taxRate.toStringAsFixed(1)}%)',
                _taxAmount,
              ),
            if (_shippingAmount > 0)
              _buildPriceRow('Shipping', _shippingAmount),
            if (_tipAmount > 0) _buildPriceRow('Tip', _tipAmount),
            Divider(),
            _buildPriceRow('TOTAL', _finalTotal, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
      String label,
      double amount, {
        bool isDiscount = false,
        bool isTotal = false,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : Colors.black,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}${Constants.CURRENCY_NAME}${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.green
                  : (isTotal ? Colors.green[700] : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAdditionalOptionButton(
                    'Additional Discount',
                    _additionalDiscount > 0
                        ? '${Constants.CURRENCY_NAME}${_additionalDiscount.toStringAsFixed(2)}'
                        : 'Add',
                    _showAdditionalDiscountDialog,
                    color: _additionalDiscount > 0 ? Colors.green : null,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildAdditionalOptionButton(
                    'Shipping',
                    _shippingAmount > 0
                        ? '${Constants.CURRENCY_NAME}${_shippingAmount.toStringAsFixed(2)}'
                        : 'Add',
                    _showShippingDialog,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAdditionalOptionButton(
                    'Tip',
                    _tipAmount > 0
                        ? '${Constants.CURRENCY_NAME}${_tipAmount.toStringAsFixed(2)}'
                        : 'Add',
                    _showTipDialog,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Container(), // Empty for alignment
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalOptionButton(
      String title,
      String value,
      VoidCallback onTap, {
        Color? color,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return ChoiceChip(
                  label: Text(_getPaymentMethodName(method)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPaymentMethod = method);
                    }
                  },
                  selectedColor: Colors.blue[100],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blue[800] : Colors.grey[800],
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Credit Card';
      case 'mobile_money':
        return 'Mobile Money';
      case 'credit':
        return 'Store Credit';
      default:
        return method;
    }
  }

  Widget _buildActionButtons() {
    final isOnline = _posService.isOnline;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          if (_errorMessage != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),

          if (!isOnline)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Order will be saved locally and synced when online',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: _isProcessing
                ? ElevatedButton(
              onPressed: null,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
                : ElevatedButton(
              onPressed: widget.cartItems.isEmpty ? null : _processOrder,
              child: Text(
                isOnline ? 'PROCESS PAYMENT' : 'SAVE OFFLINE ORDER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSettings) {
      return Scaffold(
        appBar: AppBar(title: Text('Checkout')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading settings...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout'),
        backgroundColor: _posService.isOnline
            ? Colors.blue[700]
            : Colors.orange[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Customer Section
                  _buildCustomerSection(),
                  SizedBox(height: 16),

                  // Order Summary
                  _buildOrderSummary(),
                  SizedBox(height: 16),

                  // Additional Options
                  _buildAdditionalOptions(),
                  SizedBox(height: 16),

                  // Price Breakdown
                  _buildPriceBreakdown(),
                  SizedBox(height: 16),

                  // Payment Section
                  _buildPaymentSection(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _additionalDiscountController.dispose();
    _shippingController.dispose();
    _tipController.dispose();
    super.dispose();
  }
}
// Enhanced InvoiceOptionsBottomSheet to use settings
class InvoiceOptionsBottomSheet extends StatelessWidget {
  final Order order;
  final Customer? customer;
  final Map<String, dynamic> businessInfo;
  final Map<String, dynamic> invoiceSettings;

  const InvoiceOptionsBottomSheet({
    super.key,
    required this.order,
    this.customer,
    required this.businessInfo,
    required this.invoiceSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Order Completed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Order #${order.number} has been processed successfully',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Total: ${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          SizedBox(height: 24),

          // Invoice Options
          if (invoiceSettings['autoPrint'] ?? false)
            ListTile(
              leading: Icon(Icons.print, color: Colors.blue),
              title: Text('Auto-printing invoice...'),
              trailing: CircularProgressIndicator(),
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Generate and print invoice
                      _printInvoice(context);
                    },
                    icon: Icon(Icons.print),
                    label: Text('Print Invoice'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.done),
                    label: Text('Continue'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _printInvoice(BuildContext context) {
    // Use business info and invoice settings for printing
    final invoice = Invoice.fromOrder(
      order,
      customer,
      businessInfo,
      invoiceSettings,
      templateType: invoiceSettings['defaultTemplate'] ?? 'traditional',
    );

    // Print the invoice
    InvoiceService().printInvoice(invoice);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Invoice sent to printer')));

    Navigator.pop(context);
  }
}

// Product Management Screen
class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  _ProductManagementScreenState createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<Product> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // In ProductManagementScreen - UPDATE the _loadProducts method
  Future<void> _loadProducts() async {
    final LocalDatabase localDb = LocalDatabase();
    try {
      List<Product> products;

      if (_posService.isOnline) {
        // Load from online source
        products = await _posService.fetchProducts(limit: 100);
      } else {
        // Load ALL products from local database, not just limited ones
        products = await localDb.getAllProducts();
      }

      setState(() {
        _products.clear();
        _products.addAll(products);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddProductScreen()),
    ).then((_) => _loadProducts());
  }

  void _navigateToRestockProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RestockProductScreen()),
    ).then((_) => _loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text('Error: $_errorMessage'))
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToAddProduct,
                          icon: Icon(Icons.add),
                          label: Text('Add New Product'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToRestockProduct,
                          icon: Icon(Icons.inventory),
                          label: Text('Restock Product'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return ProductManagementCard(
                        product: product,
                        onEdit: () {
                          // Navigate to edit product screen
                        },
                        onDelete: () {
                          _deleteProduct(product.id);
                        },
                        onRestock: () {
                          _showRestockDialog(product);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _posService.deleteProduct(productId);
        _loadProducts();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Product deleted')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete product: $e')));
      }
    }
  }

  void _showRestockDialog(Product product) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${product.stockQuantity}'),
            SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity to add',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                try {
                  await _posService.restockProduct(product.id, quantity);
                  Navigator.of(context).pop();
                  _loadProducts();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Product restocked')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to restock: $e')),
                  );
                }
              }
            },
            child: Text('Restock'),
          ),
        ],
      ),
    );
  }
}

// Product Management Card
class ProductManagementCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestock;

  const ProductManagementCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'SKU: ${product.sku}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)} • Stock: ${product.stockQuantity}',
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'restock', child: Text('Restock')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'restock':
                    onRestock();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Add Product Screen
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final List<Category> _categories = [];
  final List<String> _selectedCategoryIds = [];
  bool _isLoading = false;
  bool _isCheckingBarcode = false;
  String? _barcodeError;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _posService.getCategories();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      print('Failed to load categories: $e');
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<bool> _isBarcodeDuplicate(String barcode) async {
    if (barcode.isEmpty) return false;
    setState(() {
      _isCheckingBarcode = true;
      _barcodeError = null;
    });
    try {
      if (_posService.isOnline) {
        final onlineProducts = await _posService.searchProductsBySKU(barcode);
        if (onlineProducts.isNotEmpty) {
          return true;
        }
      }
      final LocalDatabase localDb = LocalDatabase();
      final localProduct = await localDb.getProductBySku(barcode);
      return localProduct != null;
    } catch (e) {
      print('Error checking barcode duplicate: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isCheckingBarcode = false);
      }
    }
  }

  Future<void> _scanAndSetBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'add',
    );
    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        _skuController.text = barcode;
        _barcodeError = null;
      });
      Future.delayed(Duration(milliseconds: 500), () {
        _validateBarcodeUniqueness(barcode);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode scanned: $barcode'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _validateBarcodeUniqueness(String barcode) async {
    if (barcode.isEmpty) return;
    final isDuplicate = await _isBarcodeDuplicate(barcode);
    if (mounted) {
      setState(() {
        if (isDuplicate) {
          _barcodeError = 'This barcode is already used by another product';
        } else {
          _barcodeError = null;
        }
      });
    }
  }

  Future<bool> _validateForm() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    final barcode = _skuController.text.trim();
    if (barcode.isNotEmpty) {
      final isDuplicate = await _isBarcodeDuplicate(barcode);
      if (isDuplicate) {
        setState(() {
          _barcodeError = 'This barcode is already used by another product';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please use a unique barcode'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitProduct() async {
    if (!await _validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final selectedCategories = _categories
          .where((cat) => _selectedCategoryIds.contains(cat.id))
          .toList();

      final product = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        sku: _skuController.text.trim(),
        price: double.parse(_priceController.text),
        stockQuantity: int.parse(_stockController.text),
        inStock: true,
        stockStatus: 'instock',
        description: _descriptionController.text,
        status: 'publish',
        categories: selectedCategories,
      );

      await _posService.addProduct(product, _selectedImages);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _selectedImages.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 50,
                        color: Colors.grey,
                      ),
                      Text('Tap to add product images'),
                      SizedBox(height: 4),
                      Text(
                        'Max 5 images',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeImage(index),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (_selectedImages.length < 5)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FloatingActionButton.small(
                            onPressed: _pickImages,
                            child: Icon(Icons.add),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedImages.length}/5 images selected. Tap image to remove.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        _isLoadingCategories
            ? CircularProgressIndicator()
            : _categories.isEmpty
            ? Text(
                'No categories available. Add categories in settings.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategoryIds.contains(category.id);
                  return FilterChip(
                    label: Text(category.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategoryIds.add(category.id);
                        } else {
                          _selectedCategoryIds.remove(category.id);
                        }
                      });
                    },
                    selectedColor: Colors.blue[100],
                    checkmarkColor: Colors.blue[800],
                  );
                }).toList(),
              ),
        SizedBox(height: 8),
        if (_selectedCategoryIds.isNotEmpty)
          Text(
            'Selected: ${_selectedCategoryIds.length} categor${_selectedCategoryIds.length == 1 ? 'y' : 'ies'}',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _skuController,
          decoration: InputDecoration(
            labelText: 'SKU/Barcode',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.qr_code),
            suffixIcon: _isCheckingBarcode
                ? Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.qr_code_scanner),
                    onPressed: _scanAndSetBarcode,
                    tooltip: 'Scan Barcode',
                  ),
            errorText: _barcodeError,
          ),
          onChanged: (value) {
            if (_barcodeError != null && value != _skuController.text) {
              setState(() => _barcodeError = null);
            }
            if (value.isNotEmpty && value.length >= 3) {
              Future.delayed(Duration(milliseconds: 1000), () {
                if (mounted && value == _skuController.text) {
                  _validateBarcodeUniqueness(value);
                }
              });
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter SKU or scan barcode';
            }
            if (_barcodeError != null) {
              return _barcodeError;
            }
            return null;
          },
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Barcode must be unique. We\'ll check for duplicates automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        if (_barcodeError != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _barcodeError!,
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: _isLoading
              ? ElevatedButton(
                  onPressed: null,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: _submitProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _barcodeError != null ? Colors.grey : null,
                  ),
                  child: Text(
                    'ADD PRODUCT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New Product')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildImagePickerSection(),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter product name' : null,
              ),
              SizedBox(height: 16),
              _buildCategorySelection(),
              SizedBox(height: 16),
              _buildBarcodeField(),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: Constants.CURRENCY_NAME,
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter price';
                  if (double.tryParse(value!) == null)
                    return 'Please enter valid price';
                  if (double.parse(value) <= 0)
                    return 'Price must be greater than 0';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true)
                    return 'Please enter stock quantity';
                  if (int.tryParse(value!) == null)
                    return 'Please enter valid quantity';
                  if (int.parse(value) < 0) return 'Stock cannot be negative';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Restock Product Screen
class RestockProductScreen extends StatefulWidget {
  const RestockProductScreen({super.key});

  @override
  _RestockProductScreenState createState() => _RestockProductScreenState();
}

class _RestockProductScreenState extends State<RestockProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final List<Product> _allProducts = [];
  Product? _selectedProduct;
  final bool _isScanning = false;
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  final FocusNode _quantityFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    _loadAllProducts();
  }

  @override
  void dispose() {
    _quantityFocusNode.dispose();
    super.dispose();
  }

  // In RestockProductScreen - UPDATE the _loadAllProducts method
  Future<void> _loadAllProducts() async {
    setState(() => _isLoadingProducts = true);
    final LocalDatabase localDb = LocalDatabase();
    try {
      List<Product> products;

      if (_posService.isOnline) {
        products = await _posService.fetchProducts(limit: 1000);
      } else {
        // Load ALL products when offline
        products = await localDb.getAllProducts();
      }

      setState(() {
        _allProducts.clear();
        _allProducts.addAll(products);
      });
    } catch (e) {
      print('Failed to load products: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'restock',
    );
    if (barcode != null && barcode.isNotEmpty) {
      _barcodeController.text = barcode;
      await _searchProductByBarcode(barcode);
    }
  }

  Future<void> _searchProductByBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      List<Product> products = await _posService.searchProductsBySKU(barcode);

      if (products.isEmpty) {
        print('Primary search failed, trying local search...');
        products = _allProducts.where((p) => p.sku == barcode).toList();
      }

      if (products.isNotEmpty) {
        final product = products.first;
        setState(() {
          _selectedProduct = product;
        });

        _quantityController.text = '1';
        FocusScope.of(context).requestFocus(_quantityFocusNode);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product found: ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _selectedProduct = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found with barcode: $barcode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _selectedProduct = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restockProduct() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a product first')));
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter valid quantity')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _posService.restockProduct(_selectedProduct!.id, quantity);

      // Show appropriate message based on online status
      if (_posService.isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedProduct!.name} restocked with $quantity items!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadAllProducts();
      Navigator.of(context).pop();
    } catch (e) {
      // Even if there's an error, it might be because we're saving offline
      final errorMessage = e.toString();
      if (errorMessage.contains('offline') ||
          errorMessage.contains('Saved offline')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadAllProducts();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProduct = null;
      _barcodeController.clear();
      _quantityController.text = '1';
    });
  }

  int get _newStockQuantity {
    final currentStock = _selectedProduct?.stockQuantity ?? 0;
    final addedQuantity = int.tryParse(_quantityController.text) ?? 0;
    return currentStock + addedQuantity;
  }

  bool get _canRestock {
    return _selectedProduct != null &&
        _quantityController.text.isNotEmpty &&
        (int.tryParse(_quantityController.text) ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Restock Product'),
        actions: [
          if (_selectedProduct != null)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear Selection',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllProducts,
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: _isLoadingProducts
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Manual Product Selection
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.list, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Select Product Manually',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<Product>(
                            initialValue: _selectedProduct,
                            decoration: InputDecoration(
                              labelText: 'Choose Product',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            items: _allProducts.map((product) {
                              return DropdownMenuItem(
                                value: product,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      product.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'SKU: ${product.sku} | Stock: ${product.stockQuantity}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (product) {
                              setState(() {
                                _selectedProduct = product;
                                if (product != null) {
                                  _barcodeController.text = product.sku;
                                  _quantityController.text = '1';
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_quantityFocusNode);
                                }
                              });
                            },
                            isExpanded: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // OR Divider
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Barcode Input Section
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.qr_code, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Scan Barcode',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _barcodeController,
                                  decoration: InputDecoration(
                                    labelText: 'Barcode/SKU',
                                    border: OutlineInputBorder(),
                                    suffixIcon: _isLoading
                                        ? Padding(
                                            padding: EdgeInsets.all(12),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : _barcodeController.text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear),
                                            onPressed: () {
                                              _barcodeController.clear();
                                              setState(() {});
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                    if (value.length >= 3) {
                                      _searchProductByBarcode(value);
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              _isScanning
                                  ? CircularProgressIndicator()
                                  : IconButton(
                                      icon: Icon(
                                        Icons.qr_code_scanner,
                                        size: 32,
                                      ),
                                      onPressed: _scanBarcode,
                                      tooltip: 'Scan Barcode',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.blue[50],
                                        padding: EdgeInsets.all(16),
                                      ),
                                    ),
                            ],
                          ),
                          if (_barcodeController.text.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Press scan button or enter to search',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Product Info Section
                  if (_selectedProduct != null) ...[
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Selected Product',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    image: _selectedProduct!.imageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              _selectedProduct!.imageUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _selectedProduct!.imageUrl == null
                                      ? Icon(
                                          Icons.inventory,
                                          color: Colors.grey[400],
                                        )
                                      : null,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedProduct!.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'SKU: ${_selectedProduct!.sku}',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Current Stock: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _selectedProduct!.stockQuantity
                                                .toString(),
                                            style: TextStyle(
                                              color: _selectedProduct!.inStock
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Price: ${Constants.CURRENCY_NAME}${_selectedProduct!.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Quantity Input Section
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.add_circle, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Restock Quantity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            TextField(
                              controller: _quantityController,
                              focusNode: _quantityFocusNode,
                              decoration: InputDecoration(
                                labelText: 'Quantity to Add',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.add),
                                hintText: 'Enter quantity',
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _quantityController.text = '1';
                                    setState(() {});
                                  },
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'New Total Stock:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$_newStockQuantity',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  Spacer(),

                  // Restock Button
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isLoading
                              ? ElevatedButton(
                                  onPressed: null,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _canRestock
                                      ? _restockProduct
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _canRestock
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'RESTOCK PRODUCT',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}

// Barcode Service
class BarcodeService {
  static Future<BarcodeScanResult> scanBarcode(BuildContext context) async {
    try {
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
      );

      if (barcode != null && barcode.isNotEmpty) {
        return BarcodeScanResult(barcode: barcode, success: true);
      } else {
        return BarcodeScanResult(
          barcode: '',
          success: false,
          error: 'Scan cancelled',
        );
      }
    } catch (e) {
      return BarcodeScanResult(
        barcode: '',
        success: false,
        error: e.toString(),
      );
    }
  }
}

class BarcodeScanResult {
  final String barcode;
  final bool success;
  final String? error;

  BarcodeScanResult({required this.barcode, required this.success, this.error});
}

// Barcode Scanner Screen
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan Barcode'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return Icon(Icons.flash_on, color: Colors.yellow);
                }
                return Icon(Icons.flash_on, color: Colors.yellow);
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                _hasScanned = true;
                final barcode = barcodes.first.rawValue;
                if (barcode != null) {
                  Navigator.of(context).pop(barcode);
                }
              }
            },
          ),
          CustomPaint(painter: ScannerOverlay()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// Barcode Manual Input Dialog
class BarcodeManualInputDialog extends StatefulWidget {
  final Function(String) onBarcodeScanned;

  const BarcodeManualInputDialog({super.key, required this.onBarcodeScanned});

  @override
  _BarcodeManualInputDialogState createState() =>
      _BarcodeManualInputDialogState();
}

class _BarcodeManualInputDialogState extends State<BarcodeManualInputDialog> {
  final TextEditingController _barcodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter Barcode'),
      content: TextField(
        controller: _barcodeController,
        decoration: InputDecoration(labelText: 'Barcode'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final barcode = _barcodeController.text.trim();
            if (barcode.isNotEmpty) {
              Navigator.of(context).pop();
              widget.onBarcodeScanned(barcode);
            }
          },
          child: Text('Search'),
        ),
      ],
    );
  }
}

// Scanner Overlay
class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scanAreaSize = size.width * 0.7;
    final scanRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scanAreaSize,
      height: scanAreaSize * 0.6,
    );

    final scanPath = Path()..addRect(scanRect);
    final overlayPath = Path.combine(PathOperation.difference, path, scanPath);

    canvas.drawPath(overlayPath, paint);
    canvas.drawRect(
      scanRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Add this to your main screen navigation
// Enhanced Scanning Preferences Service
class ScanningPreferencesService {
  static const String _defaultScanningOptionKey = 'default_scanning_option';
  static const String _isDefaultEnabledKey = 'is_default_enabled';
  static const String _recentBarcodesKey = 'recent_barcodes';
  static const int _maxRecentBarcodes = 10;

  // Default scanning option methods
  static Future<void> setDefaultScanningOption(ScanningOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultScanningOptionKey, option.name);
  }

  static Future<ScanningOption?> getDefaultScanningOption() async {
    final prefs = await SharedPreferences.getInstance();
    final optionName = prefs.getString(_defaultScanningOptionKey);
    if (optionName == null) return null;

    try {
      return ScanningOption.values.firstWhere(
        (option) => option.name == optionName,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<void> setDefaultEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDefaultEnabledKey, enabled);
  }

  static Future<bool> isDefaultEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDefaultEnabledKey) ?? false;
  }

  static Future<void> resetDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_defaultScanningOptionKey);
    await prefs.remove(_isDefaultEnabledKey);
  }

  // Recent barcodes methods
  static Future<void> addRecentBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> recentBarcodes = await getRecentBarcodes();

    // Remove if already exists (to avoid duplicates)
    recentBarcodes.removeWhere((b) => b == barcode);

    // Add to beginning
    recentBarcodes.insert(0, barcode);

    // Limit the list size
    if (recentBarcodes.length > _maxRecentBarcodes) {
      recentBarcodes = recentBarcodes.sublist(0, _maxRecentBarcodes);
    }

    await prefs.setStringList(_recentBarcodesKey, recentBarcodes);
  }

  static Future<List<String>> getRecentBarcodes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentBarcodesKey) ?? [];
  }

  static Future<void> clearRecentBarcodes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentBarcodesKey);
  }

  // Quick access to check if default scanning is available
  static Future<bool> shouldUseDefaultScanning() async {
    final isEnabled = await isDefaultEnabled();
    final defaultOption = await getDefaultScanningOption();
    return isEnabled && defaultOption != null;
  }
}

// Universal Scanning Service
class UniversalScanningService {
  static Future<String?> scanBarcode(
    BuildContext context, {
    String purpose = 'scan',
  }) async {
    // Check if default scanning is enabled
    final shouldUseDefault =
        await ScanningPreferencesService.shouldUseDefaultScanning();
    final defaultOption =
        await ScanningPreferencesService.getDefaultScanningOption();

    if (shouldUseDefault && defaultOption != null) {
      return await _executeScanningOption(
        context,
        defaultOption,
        purpose: purpose,
      );
    }

    // Show options sheet if no default is set
    return await _showScanningOptionsSheet(context, purpose: purpose);
  }

  static Future<String?> _executeScanningOption(
    BuildContext context,
    ScanningOption option, {
    String purpose = 'scan',
  }) async {
    switch (option) {
      case ScanningOption.camera:
        return await _startCameraBarcodeScan(context, purpose: purpose);
      case ScanningOption.hardware:
        return await _navigateToHardwareScannerScreen(
          context,
          purpose: purpose,
        );
      case ScanningOption.manual:
        return await _showManualBarcodeInput(context, purpose: purpose);
    }
  }

  static Future<String?> _showScanningOptionsSheet(
    BuildContext context, {
    String purpose = 'scan',
  }) async {
    return await showModalBottomSheet<String?>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          _buildUniversalBarcodeOptionsSheet(context, purpose: purpose),
    );
  }

  static Widget _buildUniversalBarcodeOptionsSheet(
    BuildContext context, {
    String purpose = 'scan',
  }) {
    String title;
    switch (purpose) {
      case 'search':
        title = 'Search Product by Barcode';
      case 'restock':
        title = 'Restock Product by Barcode';
      case 'add':
        title = 'Add Product Barcode';
      default:
        title = 'Scan Barcode';
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // Default Option Toggle
          _buildDefaultOptionToggle(context),
          SizedBox(height: 8),

          Divider(),
          SizedBox(height: 8),

          // Recent Barcodes (if any)
          _buildRecentBarcodesSection(context),

          // Scanning Options
          _buildUniversalBarcodeOption(
            context,
            icon: Icons.camera_alt,
            title: 'Camera Scan',
            subtitle: 'Use device camera',
            onTap: () async {
              final result = await _startCameraBarcodeScan(
                context,
                purpose: purpose,
              );
              Navigator.of(context).pop(result);
              return null;
            },
            onSetDefault: () =>
                _setDefaultScanningOption(context, ScanningOption.camera),
          ),
          _buildUniversalBarcodeOption(
            context,
            icon: Icons.keyboard_return,
            title: 'Hardware Scanner',
            subtitle: 'Use a connected barcode scanner',
            onTap: () async {
              final result = await _navigateToHardwareScannerScreen(
                context,
                purpose: purpose,
              );
              Navigator.of(context).pop(result);
              return null;
            },
            onSetDefault: () =>
                _setDefaultScanningOption(context, ScanningOption.hardware),
          ),
          _buildUniversalBarcodeOption(
            context,
            icon: Icons.keyboard,
            title: 'Manual Entry',
            subtitle: 'Type barcode manually',
            onTap: () async {
              final result = await _showManualBarcodeInput(
                context,
                purpose: purpose,
              );
              Navigator.of(context).pop(result);
              return null;
            },
            onSetDefault: () =>
                _setDefaultScanningOption(context, ScanningOption.manual),
          ),

          SizedBox(height: 16),

          // Reset Defaults Button
          _buildResetDefaultsButton(context),
          SizedBox(height: 8),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Camera Scanning
  static Future<String?> _startCameraBarcodeScan(
    BuildContext context, {
    String purpose = 'scan',
  }) async {
    try {
      final result = await BarcodeService.scanBarcode(context);

      if (result.success && result.barcode.isNotEmpty) {
        await ScanningPreferencesService.addRecentBarcode(result.barcode);
        return result.barcode;
      } else if (result.barcode == '-1') {
        // Cancelled
        return null;
      } else {
        _showSnackBar(context, result.error ?? 'Scan failed', Colors.red);
        return null;
      }
    } catch (e) {
      _showSnackBar(context, 'Camera scan failed: $e', Colors.red);
      return null;
    }
  }

  // Hardware Scanner
  static Future<String?> _navigateToHardwareScannerScreen(
    BuildContext context, {
    String purpose = 'scan',
  }) async {
    final scannedCode = await Navigator.of(
      context,
    ).push<String?>(MaterialPageRoute(builder: (_) => HardwareScannerScreen()));

    if (scannedCode != null && scannedCode.isNotEmpty) {
      await ScanningPreferencesService.addRecentBarcode(scannedCode);
    }

    return scannedCode;
  }

  // Manual Input
  static Future<String?> _showManualBarcodeInput(
    BuildContext context, {
    String purpose = 'scan',
  }) async {
    String? barcode = await showDialog<String>(
      context: context,
      builder: (context) => BarcodeManualInputDialog(
        onBarcodeScanned: (barcode) {
          Navigator.of(context).pop(barcode);
        },
      ),
    );

    if (barcode != null && barcode.isNotEmpty) {
      await ScanningPreferencesService.addRecentBarcode(barcode);
    }

    return barcode;
  }

  // UI Components (similar to previous implementation but static)
  static Widget _buildDefaultOptionToggle(BuildContext context) {
    return FutureBuilder<bool>(
      future: ScanningPreferencesService.isDefaultEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;
        final defaultOption = snapshot.hasData
            ? ScanningPreferencesService.getDefaultScanningOption()
            : null;

        return Card(
          color: Colors.blue[50],
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Scanning',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isEnabled)
                        FutureBuilder<ScanningOption?>(
                          future:
                              ScanningPreferencesService.getDefaultScanningOption(),
                          builder: (context, snapshot) {
                            final option = snapshot.data;
                            if (option != null && snapshot.hasData) {
                              return Text(
                                'Currently: ${option.title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              );
                            }
                            return SizedBox();
                          },
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (value) async {
                    await ScanningPreferencesService.setDefaultEnabled(value);
                    if (context.mounted) {
                      _showDefaultOptionStatus(context, value);
                    }
                  },
                  activeThumbColor: Colors.blue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildRecentBarcodesSection(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: ScanningPreferencesService.getRecentBarcodes(),
      builder: (context, snapshot) {
        final recentBarcodes = snapshot.data ?? [];
        if (recentBarcodes.isEmpty) return SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Barcodes:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: recentBarcodes.map((barcode) {
                return ActionChip(
                  label: Text(barcode),
                  onPressed: () {
                    Navigator.of(context).pop(barcode);
                  },
                  avatar: Icon(Icons.history, size: 16),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  static Widget _buildUniversalBarcodeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<String?> Function() onTap,
    required VoidCallback onSetDefault,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue, size: 30),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, size: 20),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'set_default',
              child: Row(
                children: [
                  Icon(Icons.star, size: 20, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Set as Default'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'set_default') {
              onSetDefault();
            }
          },
        ),
        onTap: () async {
          final result = await onTap();
          if (context.mounted) {
            Navigator.of(context).pop(result);
          }
        },
      ),
    );
  }

  static Widget _buildResetDefaultsButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: ScanningPreferencesService.isDefaultEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;

        if (!isEnabled) return SizedBox();

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showResetConfirmationDialog(context),
            icon: Icon(Icons.restore, size: 18),
            label: Text('Reset Default Settings'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orange),
            ),
          ),
        );
      },
    );
  }

  // Dialog and confirmation methods
  static Future<void> _setDefaultScanningOption(
    BuildContext context,
    ScanningOption option,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Default Scanning'),
        content: Text(
          'Set "${option.title}" as your default scanning method? '
          'This will skip the selection menu and go directly to scanning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Set as Default'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ScanningPreferencesService.setDefaultScanningOption(option);
      await ScanningPreferencesService.setDefaultEnabled(true);

      if (context.mounted) {
        _showDefaultSetSuccess(context, option);
      }
    }
  }

  static void _showDefaultSetSuccess(
    BuildContext context,
    ScanningOption option,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Default scanning set to ${option.title}')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  static void _showDefaultOptionStatus(BuildContext context, bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'Default scanning enabled' : 'Default scanning disabled',
        ),
        backgroundColor: enabled ? Colors.green : Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  static void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Default Settings'),
        content: Text(
          'Are you sure you want to reset all default scanning settings? '
          'This will clear your preferred scanning method.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ScanningPreferencesService.resetDefaults();
              if (context.mounted) {
                Navigator.of(context).pop();
                _showResetSuccess(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Reset Defaults'),
          ),
        ],
      ),
    );
  }

  static void _showResetSuccess(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Default settings reset successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Scanning Options Enum
enum ScanningOption {
  camera('Camera Scan', Icons.camera_alt, 'Use device camera'),
  hardware(
    'Hardware Scanner',
    Icons.keyboard_return,
    'Use a connected barcode scanner',
  ),
  manual('Manual Entry', Icons.keyboard, 'Type barcode manually');

  final String title;
  final IconData icon;
  final String subtitle;

  const ScanningOption(this.title, this.icon, this.subtitle);
}

// Global Scanning Settings Screen
class ScanningSettingsScreen extends StatefulWidget {
  const ScanningSettingsScreen({super.key});

  @override
  _ScanningSettingsScreenState createState() => _ScanningSettingsScreenState();
}

class _ScanningSettingsScreenState extends State<ScanningSettingsScreen> {
  bool _isDefaultEnabled = false;
  ScanningOption? _currentDefaultOption;
  List<String> _recentBarcodes = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await ScanningPreferencesService.isDefaultEnabled();
    final defaultOption =
        await ScanningPreferencesService.getDefaultScanningOption();
    final recentBarcodes = await ScanningPreferencesService.getRecentBarcodes();

    if (mounted) {
      setState(() {
        _isDefaultEnabled = isEnabled;
        _currentDefaultOption = defaultOption;
        _recentBarcodes = recentBarcodes;
      });
    }
  }

  Future<void> _toggleDefaultScanning(bool value) async {
    await ScanningPreferencesService.setDefaultEnabled(value);
    setState(() {
      _isDefaultEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Default scanning enabled' : 'Default scanning disabled',
        ),
        backgroundColor: value ? Colors.green : Colors.blue,
      ),
    );
  }

  Future<void> _setDefaultOption(ScanningOption option) async {
    await ScanningPreferencesService.setDefaultScanningOption(option);
    await ScanningPreferencesService.setDefaultEnabled(true);

    setState(() {
      _currentDefaultOption = option;
      _isDefaultEnabled = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Default set to ${option.title}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _clearRecentBarcodes() async {
    await ScanningPreferencesService.clearRecentBarcodes();
    setState(() {
      _recentBarcodes.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Recent barcodes cleared')));
  }

  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset All Settings'),
        content: Text('Reset all scanning preferences to default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ScanningPreferencesService.resetDefaults();
      await ScanningPreferencesService.clearRecentBarcodes();

      setState(() {
        _isDefaultEnabled = false;
        _currentDefaultOption = null;
        _recentBarcodes.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All settings reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scanning Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Scanning Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDefaultScanningToggle(),
                    SizedBox(height: 16),
                    _buildDefaultOptionSelector(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Barcodes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildRecentBarcodesSection(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildResetButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultScanningToggle() {
    return Row(
      children: [
        Icon(Icons.auto_awesome, color: Colors.blue),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Use Default Scanning', style: TextStyle(fontSize: 16)),
              if (_isDefaultEnabled && _currentDefaultOption != null)
                Text(
                  'Current: ${_currentDefaultOption!.title}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        Switch(value: _isDefaultEnabled, onChanged: _toggleDefaultScanning),
      ],
    );
  }

  Widget _buildDefaultOptionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Scanning Method:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ScanningOption.values.map((option) {
            final isSelected = _currentDefaultOption == option;
            return ChoiceChip(
              label: Text(option.title),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _setDefaultOption(option);
                }
              },
              selectedColor: Colors.blue[100],
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[800] : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        if (!_isDefaultEnabled && _currentDefaultOption != null)
          Text(
            'Note: Turn on "Use Default Scanning" to activate ${_currentDefaultOption!.title}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildRecentBarcodesSection() {
    if (_recentBarcodes.isEmpty) {
      return Column(
        children: [
          Text('No recent barcodes'),
          SizedBox(height: 8),
          Text(
            'Scanned barcodes will appear here for quick access',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recently scanned barcodes:'),
        SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _recentBarcodes.map((barcode) {
                return Chip(
                  label: Text(
                    barcode,
                    style: TextStyle(fontFamily: 'Monospace'),
                  ),
                  backgroundColor: Colors.grey[100],
                  deleteIconColor: Colors.grey[600],
                  onDeleted: () {
                    // For individual deletion, you could implement this:
                    // _removeRecentBarcode(barcode);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: 12),
        OutlinedButton(
          onPressed: _clearRecentBarcodes,
          child: Text('Clear All Recent Barcodes'),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _resetAllSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        child: Text('Reset All Scanning Settings'),
      ),
    );
  }
}

class AddCustomerScreen extends StatefulWidget {
  final EnhancedPOSService posService;
  final Function(Customer)? onCustomerAdded;

  const AddCustomerScreen({
    super.key,
    required this.posService,
    this.onCustomerAdded,
  });

  @override
  _AddCustomerScreenState createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers and focus nodes
    final fields = [
      'firstName',
      'lastName',
      'email',
      'phone',
      'company',
      'address1',
      'address2',
      'city',
      'state',
      'postcode',
      'country',
      'notes',
    ];

    for (final field in fields) {
      _controllers[field] = TextEditingController();
      _focusNodes[field] = FocusNode();
    }

    // Add listeners for real-time validation
    for (final controller in _controllers.values) {
      controller.addListener(_validateForm);
    }
  }

  void _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  Future<void> _submitCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final customer = Customer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: _controllers['firstName']!.text.trim(),
        lastName: _controllers['lastName']!.text.trim(),
        email: _controllers['email']!.text.trim(),
        phone: _controllers['phone']!.text.trim(),
        company: _controllers['company']!.text.trim().isEmpty
            ? null
            : _controllers['company']!.text.trim(),
        address1: _controllers['address1']!.text.trim().isEmpty
            ? null
            : _controllers['address1']!.text.trim(),
        address2: _controllers['address2']!.text.trim().isEmpty
            ? null
            : _controllers['address2']!.text.trim(),
        city: _controllers['city']!.text.trim().isEmpty
            ? null
            : _controllers['city']!.text.trim(),
        state: _controllers['state']!.text.trim().isEmpty
            ? null
            : _controllers['state']!.text.trim(),
        postcode: _controllers['postcode']!.text.trim().isEmpty
            ? null
            : _controllers['postcode']!.text.trim(),
        country: _controllers['country']!.text.trim().isEmpty
            ? null
            : _controllers['country']!.text.trim(),
        notes: _controllers['notes']!.text.trim().isEmpty
            ? null
            : _controllers['notes']!.text.trim(),
        dateCreated: DateTime.now(),
      );

      // Check if customer already exists
      final existingCustomers = await widget.posService.searchCustomers(
        customer.email,
      );
      final emailExists = existingCustomers.any(
        (c) => c.email.toLowerCase() == customer.email.toLowerCase(),
      );

      if (emailExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer with this email already exists'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await widget.posService.addCustomer(customer);

      if (widget.onCustomerAdded != null) {
        widget.onCustomerAdded!(customer);
      } else {
        Navigator.pop(context, customer);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add customer: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add New Customer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    // Personal Information
                    _buildSectionHeader(
                      'Personal Information',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['firstName'],
                            focusNode: _focusNodes['firstName'],
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              hintText: 'Enter first name',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                _requiredValidator(value, 'First name'),
                            onFieldSubmitted: (_) =>
                                _focusNodes['lastName']?.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['lastName'],
                            focusNode: _focusNodes['lastName'],
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              hintText: 'Enter last name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                _requiredValidator(value, 'Last name'),
                            onFieldSubmitted: (_) =>
                                _focusNodes['email']?.requestFocus(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['email'],
                      focusNode: _focusNodes['email'],
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'customer@example.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                      onFieldSubmitted: (_) =>
                          _focusNodes['phone']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['phone'],
                      focusNode: _focusNodes['phone'],
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+1 (555) 123-4567',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          _requiredValidator(value, 'Phone number'),
                      onFieldSubmitted: (_) =>
                          _focusNodes['company']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['company'],
                      focusNode: _focusNodes['company'],
                      decoration: InputDecoration(
                        labelText: 'Company',
                        hintText: 'Enter company name',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _focusNodes['address1']?.requestFocus(),
                    ),

                    // Address Information
                    _buildSectionHeader(
                      'Address Information',
                      Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['address1'],
                      focusNode: _focusNodes['address1'],
                      decoration: InputDecoration(
                        labelText: 'Address Line 1',
                        hintText: 'Street address, P.O. box',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _focusNodes['address2']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['address2'],
                      focusNode: _focusNodes['address2'],
                      decoration: InputDecoration(
                        labelText: 'Address Line 2',
                        hintText:
                            'Apartment, suite, unit, building, floor, etc.',
                        prefixIcon: Icon(Icons.home_work),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _focusNodes['city']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['city'],
                            focusNode: _focusNodes['city'],
                            decoration: InputDecoration(
                              labelText: 'City',
                              hintText: 'Enter city',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['state']?.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['state'],
                            focusNode: _focusNodes['state'],
                            decoration: InputDecoration(
                              labelText: 'State/Province',
                              hintText: 'Enter state',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['postcode']?.requestFocus(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['postcode'],
                            focusNode: _focusNodes['postcode'],
                            decoration: InputDecoration(
                              labelText: 'Postal Code',
                              hintText: 'Enter postal code',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['country']?.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['country'],
                            focusNode: _focusNodes['country'],
                            decoration: InputDecoration(
                              labelText: 'Country',
                              hintText: 'Enter country',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['notes']?.requestFocus(),
                          ),
                        ),
                      ],
                    ),

                    // Additional Information
                    _buildSectionHeader(
                      'Additional Information',
                      Icons.note_outlined,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['notes'],
                      focusNode: _focusNodes['notes'],
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Any additional notes about the customer...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isLoading
          ? ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: _isFormValid ? _submitCustomer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                foregroundColor: _isFormValid
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                'ADD CUSTOMER',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }
}

class CustomerSelectionScreen extends StatefulWidget {
  final EnhancedPOSService posService;
  final CustomerSelection? initialSelection;

  const CustomerSelectionScreen({
    super.key,
    required this.posService,
    this.initialSelection,
  });

  @override
  _CustomerSelectionScreenState createState() =>
      _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Customer> _customers = [];
  final List<Customer> _searchResults = [];
  bool _isLoading = false;
  bool _showSearchResults = false;
  CustomerSelection _selectedCustomer = CustomerSelection(useDefault: true);
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelection != null) {
      _selectedCustomer = widget.initialSelection!;
    }
    _loadCustomers();
  }

  // Add this method to get all customers
  Future<void> _loadCustomers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final customers = await widget.posService.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers.clear();
          _customers.addAll(customers);
        });
      }
    } catch (e) {
      print('Failed to load customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customers'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchTextChanged(String query) {
    // Debounce search to avoid too many API calls
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _searchResults.clear();
      _searchResults.addAll(
        _customers
            .where(
              (customer) =>
                  customer.fullName.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  customer.email.toLowerCase().contains(query.toLowerCase()) ||
                  customer.phone.contains(query) ||
                  (customer.company?.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ??
                      false),
            )
            .toList(),
      );
      _showSearchResults = true;
    });
  }

  void _selectCustomer(Customer? customer) {
    setState(() {
      _selectedCustomer = CustomerSelection(
        customer: customer,
        useDefault: customer == null,
      );
    });
  }

  void _createNewCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(
          posService: widget.posService,
          onCustomerAdded: (customer) {
            _loadCustomers(); // Refresh the list
            _selectCustomer(customer);
            Navigator.pop(context, _selectedCustomer);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Customer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1),
            onPressed: _createNewCustomer,
            tooltip: 'Add New Customer',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers by name, email, or phone...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged: _onSearchTextChanged,
            ),
          ),

          // Default Customer Option
          _buildDefaultCustomerOption(),

          // Results Header
          if (_showSearchResults && _searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Search Results (${_searchResults.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

          // Customer List
          Expanded(
            child: _isLoading ? _buildLoadingState() : _buildCustomerList(),
          ),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDefaultCustomerOption() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _selectedCustomer.useDefault
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline, color: Colors.grey[600]),
        ),
        title: Text(
          'Walk-in Customer',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('Use for anonymous sales'),
        trailing: _selectedCustomer.useDefault
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: () => _selectCustomer(null),
      ),
    );
  }

  Widget _buildLoadingState() {
    final _posService = EnhancedPOSService();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.blue[700]!),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Loading Real Business Data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fetching live data from Firestore',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          SizedBox(height: 16),
          StreamBuilder<bool>(
            stream: _posService.onlineStatusStream,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      size: 14,
                      color: isOnline ? Colors.green : Colors.orange,
                    ),
                    SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online - Live Data' : 'Offline - Local Data',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList() {
    final displayCustomers = _showSearchResults ? _searchResults : _customers;

    if (displayCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _showSearchResults
                  ? 'No customers found'
                  : 'No customers available',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showSearchResults
                  ? 'Try a different search term'
                  : 'Add your first customer to get started',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            if (!_showSearchResults) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _createNewCustomer,
                icon: Icon(Icons.person_add),
                label: Text('Add First Customer'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: displayCustomers.length,
      itemBuilder: (context, index) {
        final customer = displayCustomers[index];
        final isSelected = _selectedCustomer.customer?.id == customer.id;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              customer.displayName,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.email),
                if (customer.phone.isNotEmpty) Text(customer.phone),
                if (customer.orderCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${customer.orderCount} ${customer.orderCount == 1 ? 'order' : 'orders'} • ${Constants.CURRENCY_NAME}${customer.totalSpent.toStringAsFixed(2)} spent',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => _selectCustomer(customer),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selectedCustomer),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Select Customer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
}
// REPLACE the entire ReturnsManagementScreen class:

// REPLACE the entire ReturnsManagementScreen class:
class ReturnsManagementScreen extends StatefulWidget {
  const ReturnsManagementScreen({super.key});

  @override
  _ReturnsManagementScreenState createState() =>
      _ReturnsManagementScreenState();
}

class _ReturnsManagementScreenState extends State<ReturnsManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<ReturnRequest> _returns = [];
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkOnlineStatus();
    _loadReturns();
  }

  Future<void> _checkOnlineStatus() async {
    final isOnline = _posService.isOnline;
    setState(() {
      _isOnline = isOnline;
    });
  }

  Future<void> _loadReturns() async {
    setState(() => _isLoading = true);

    try {
      final returns = await _posService.getAllReturns(limit: 50);
      setState(() {
        _returns.clear();
        _returns.addAll(returns);
      });
    } catch (e) {
      print('Failed to load returns: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load returns: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToCreateReturnWithOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchOrderForReturnScreen()),
    ).then((selectedOrder) {
      if (selectedOrder != null && selectedOrder is Order) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CreateReturnScreen(selectedOrder: selectedOrder),
          ),
        ).then((_) => _loadReturns());
      }
    });
  }

  void _navigateToReturnAnyProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReturnAnyProductScreen()),
    ).then((_) => _loadReturns());
  }

  void _viewReturnDetails(ReturnRequest returnRequest) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnDetailsScreen(returnRequest: returnRequest),
      ),
    );
  }

  void _showSyncStatus() {
    final pendingCount = _returns.where((ret) => ret.needsSync).length;

    if (pendingCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$pendingCount returns pending sync'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All returns are synced'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingSyncCount = _returns.where((ret) => ret.needsSync).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Returns & Refunds'),
        actions: [
          if (pendingSyncCount > 0)
            Badge(
              label: Text(pendingSyncCount.toString()),
              child: IconButton(
                icon: Icon(Icons.sync_problem),
                onPressed: _showSyncStatus,
                tooltip: '$pendingSyncCount returns pending sync',
              ),
            ),
          if (!_isOnline)
            IconButton(
              icon: Icon(Icons.cloud_off, color: Colors.orange),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Working in offline mode - Returns will sync when online',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              tooltip: 'Offline Mode',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReturns,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 20, color: Colors.orange[800]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Returns will be saved locally and synced when online',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Actions
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Process New Return',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                // Option 1: Return with Order
                Card(
                  child: ListTile(
                    leading: Icon(Icons.receipt_long, color: Colors.blue),
                    title: Text('Return with Order'),
                    subtitle: Text('Find order by number or barcode'),
                    trailing: Icon(Icons.arrow_forward),
                    onTap: _navigateToCreateReturnWithOrder,
                  ),
                ),
                SizedBox(height: 12),
                // Option 2: Return Any Product
                Card(
                  child: ListTile(
                    leading: Icon(Icons.shopping_bag, color: Colors.green),
                    title: Text('Return Any Product'),
                    subtitle: Text('Return without order receipt'),
                    trailing: Icon(Icons.arrow_forward),
                    onTap: _navigateToReturnAnyProduct,
                  ),
                ),
              ],
            ),
          ),
          Divider(),

          // Recent Returns Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Returns',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_returns.length} returns',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Recent Returns List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _returns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_return,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text('No returns processed yet'),
                        SizedBox(height: 8),
                        Text(
                          !_isOnline
                              ? 'Returns will be saved locally and synced when online'
                              : 'Choose an option above to process a return',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReturns,
                    child: ListView.builder(
                      itemCount: _returns.length,
                      itemBuilder: (context, index) {
                        final returnRequest = _returns[index];
                        return GestureDetector(
                          onTap: () => _viewReturnDetails(returnRequest),
                          child: EnhancedReturnRequestCard(
                            returnRequest: returnRequest,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// REPLACE the entire CreateReturnScreen class:
// ADD this new EnhancedReturnRequestCard class:
class EnhancedReturnRequestCard extends StatelessWidget {
  final ReturnRequest returnRequest;

  const EnhancedReturnRequestCard({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Return #${returnRequest.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Row(
                  children: [
                    if (returnRequest.needsSync)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sync,
                              size: 12,
                              color: Colors.orange[800],
                            ),
                            SizedBox(width: 2),
                            Text(
                              'PENDING SYNC',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(returnRequest.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        returnRequest.status.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Order: ${returnRequest.orderNumber}',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text('Items: ${returnRequest.items.length}'),
            Text(
              'Refund: ${Constants.CURRENCY_NAME}${returnRequest.refundAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            Text(
              'Method: ${_getRefundMethodDisplayName(returnRequest.refundMethod)}',
            ),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(returnRequest.dateCreated)}',
            ),
            if (returnRequest.isOffline)
              Text(
                'Created Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            SizedBox(height: 8),
            if (returnRequest.notes != null && returnRequest.notes!.isNotEmpty)
              Text(
                'Notes: ${returnRequest.notes!}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment';
      case 'cash':
        return 'Cash';
      case 'credit':
        return 'Credit Card';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
}

class CreateReturnScreen extends StatefulWidget {
  final Order? selectedOrder;

  const CreateReturnScreen({super.key, this.selectedOrder});

  @override
  _CreateReturnScreenState createState() => _CreateReturnScreenState();
}
// ADD this new class for viewing return details:

class ReturnDetailsScreen extends StatelessWidget {
  final ReturnRequest returnRequest;

  const ReturnDetailsScreen({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Return Details')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Return Header
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Return #${returnRequest.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(returnRequest.status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            returnRequest.status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Order: ${returnRequest.orderNumber}'),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(returnRequest.dateCreated)}',
                    ),
                    if (returnRequest.dateUpdated != null)
                      Text(
                        'Updated: ${DateFormat('MMM dd, yyyy - HH:mm').format(returnRequest.dateUpdated!)}',
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Refund Summary
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refund Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Refund Amount:'),
                        Text(
                          '${Constants.CURRENCY_NAME}${returnRequest.refundAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Refund Method:'),
                        Text(
                          _getRefundMethodDisplayName(
                            returnRequest.refundMethod,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Return Reason:'),
                        Text(_getReasonName(returnRequest.reason)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Returned Items
            Text(
              'Returned Items (${returnRequest.items.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: returnRequest.items.length,
                itemBuilder: (context, index) {
                  final item = returnRequest.items[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        Icons.assignment_return,
                        color: Colors.orange,
                      ),
                      title: Text(item.productName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.productSku.isNotEmpty)
                            Text('SKU: ${item.productSku}'),
                          Text(
                            'Qty: ${item.quantity} • ${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)} each',
                          ),
                          Text(
                            'Subtotal: ${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                          ),
                          Text('Reason: ${_getReasonName(item.returnReason)}'),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text('Notes: ${item.notes}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Notes
            if (returnRequest.notes != null &&
                returnRequest.notes!.isNotEmpty) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(returnRequest.notes!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment Method';
      case 'cash':
        return 'Cash Refund';
      case 'credit':
        return 'Credit Card Refund';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }

  String _getReasonName(String reasonId) {
    final reasons = {
      'defective': 'Defective Product',
      'wrong_item': 'Wrong Item Received',
      'damaged': 'Damaged Product',
      'not_as_described': 'Not as Described',
      'customer_change_mind': 'Changed Mind',
      'size_issue': 'Size Issue',
      'quality_issue': 'Quality Issue',
      'no_receipt': 'No Receipt',
    };
    return reasons[reasonId] ?? reasonId;
  }
}

class _CreateReturnScreenState extends State<CreateReturnScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<ReturnItem> _returnItems = [];
  Order? _selectedOrder;
  String _returnReason = 'defective';
  String _refundMethod = 'original';
  String? _notes;
  bool _isProcessing = false;

  final List<ReturnReason> _returnReasons = [
    ReturnReason(
      id: 'defective',
      name: 'Defective Product',
      description: 'Product not working properly',
    ),
    ReturnReason(
      id: 'wrong_item',
      name: 'Wrong Item Received',
      description: 'Received different product',
    ),
    ReturnReason(
      id: 'damaged',
      name: 'Damaged Product',
      description: 'Product arrived damaged',
    ),
    ReturnReason(
      id: 'not_as_described',
      name: 'Not as Described',
      description: 'Product different from description',
    ),
    ReturnReason(
      id: 'customer_change_mind',
      name: 'Changed Mind',
      description: 'Customer changed their mind',
    ),
    ReturnReason(
      id: 'size_issue',
      name: 'Size Issue',
      description: 'Wrong size ordered',
    ),
    ReturnReason(
      id: 'quality_issue',
      name: 'Quality Issue',
      description: 'Poor quality product',
    ),
  ];

  final List<String> _refundMethods = [
    'original',
    'cash',
    'credit',
    'store_credit',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with selected order if provided
    if (widget.selectedOrder != null) {
      _selectedOrder = widget.selectedOrder;
    }
  }

  void _searchOrder() async {
    final selectedOrder = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchOrderForReturnScreen()),
    );

    if (selectedOrder != null && selectedOrder is Order) {
      setState(() {
        _selectedOrder = selectedOrder;
      });
    }
  }

  void _showAddItemsDialog() {
    if (_selectedOrder == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Items to Return'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _selectedOrder!.lineItems.length,
            itemBuilder: (context, index) {
              final item = _selectedOrder!.lineItems[index];
              final productName =
                  item['productName']?.toString() ?? 'Unknown Product';
              final quantity = item['quantity'] as int;
              final price = (item['price'] as num).toDouble();

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(productName),
                  subtitle: Text(
                    'Qty: $quantity • ${Constants.CURRENCY_NAME}${price.toStringAsFixed(2)} each',
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add, color: Colors.green),
                    onPressed: () {
                      _addReturnItem(
                        productName,
                        item['productId']?.toString() ?? '',
                        '',
                        quantity,
                        price,
                        _returnReason,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $productName to return'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _addReturnItem(
    String productName,
    String productId,
    String sku,
    int quantity,
    double price,
    String reason,
  ) {
    setState(() {
      _returnItems.add(
        ReturnItem(
          productId: productId,
          productName: productName,
          productSku: sku,
          quantity: quantity,
          price: price,
          returnReason: reason,
        ),
      );
    });
  }

  void _removeReturnItem(int index) {
    setState(() {
      _returnItems.removeAt(index);
    });
  }

  void _updateReturnItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeReturnItem(index);
      return;
    }

    setState(() {
      _returnItems[index] = ReturnItem(
        productId: _returnItems[index].productId,
        productName: _returnItems[index].productName,
        productSku: _returnItems[index].productSku,
        quantity: newQuantity,
        price: _returnItems[index].price,
        returnReason: _returnItems[index].returnReason,
        notes: _returnItems[index].notes,
      );
    });
  }

  double get _totalRefundAmount {
    return _returnItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Future<void> _processReturn() async {
    if (_returnItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please add items to return')));
      return;
    }

    if (_selectedOrder == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select an order')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final returnRequest = ReturnRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: _selectedOrder!.id,
        orderNumber: _selectedOrder!.number,
        items: _returnItems,
        reason: _returnReason,
        status: 'completed',
        notes: _notes,
        dateCreated: DateTime.now(),
        refundAmount: _totalRefundAmount,
        refundMethod: _refundMethod,
        customerId: _selectedOrder!.lineItems.isNotEmpty
            ? _selectedOrder!.lineItems[0]['customerId']?.toString()
            : null,
      );

      await _posService.createReturn(returnRequest);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Return processed successfully! Refund: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process return: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildOrderSelection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (_selectedOrder == null)
              ElevatedButton(
                onPressed: _searchOrder,
                child: Text('Select Order'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order: ${_selectedOrder!.number}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Date: ${DateFormat('MMM dd, yyyy').format(_selectedOrder!.dateCreated)}',
                            ),
                            Text(
                              'Original Total: ${Constants.CURRENCY_NAME}${_selectedOrder!.total.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: _searchOrder,
                        tooltip: 'Change Order',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddItemsDialog,
                    icon: Icon(Icons.add_shopping_cart),
                    label: Text('Add Items from Order'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItemCard(ReturnItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.assignment_return, color: Colors.orange, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (item.productSku.isNotEmpty)
                        Text(
                          'SKU: ${item.productSku}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      Text(
                        '${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)} each',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeReturnItem(index),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Quantity:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity - 1),
                        padding: EdgeInsets.zero,
                      ),
                      Text(
                        item.quantity.toString(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity + 1),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Text(
                  'Subtotal: ${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Process Return')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOrderSelection(),
            SizedBox(height: 16),

            // Return Items
            if (_returnItems.isNotEmpty) ...[
              Text(
                'Return Items (${_returnItems.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _returnItems.length,
                  itemBuilder: (context, index) {
                    return _buildReturnItemCard(_returnItems[index], index);
                  },
                ),
              ),
            ],

            if (_returnItems.isEmpty) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text('No items added for return'),
                      SizedBox(height: 8),
                      Text(
                        'Add products from the order to process return',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Return Details
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField(
                      initialValue: _returnReason,
                      items: _returnReasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(reason.name),
                              Text(
                                reason.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _returnReason = value!),
                      decoration: InputDecoration(labelText: 'Return Reason'),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField(
                      initialValue: _refundMethod,
                      items: _refundMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(_getRefundMethodDisplayName(method)),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _refundMethod = value!),
                      decoration: InputDecoration(labelText: 'Refund Method'),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _notes = value,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),

            // Total and Action
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Refund:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isProcessing
                        ? ElevatedButton(
                            onPressed: null,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed:
                                _returnItems.isNotEmpty &&
                                    _selectedOrder != null
                                ? _processReturn
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: Text(
                              'PROCESS RETURN & REFUND',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment Method';
      case 'cash':
        return 'Cash Refund';
      case 'credit':
        return 'Credit Card Refund';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
}

class ReturnRequestCard extends StatelessWidget {
  final ReturnRequest returnRequest;

  const ReturnRequestCard({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Return #${returnRequest.id.substring(0, 8).toUpperCase()}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(returnRequest.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    returnRequest.status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Order: ${returnRequest.orderNumber}',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text('Items: ${returnRequest.items.length}'),
            Text(
              'Refund: ${Constants.CURRENCY_NAME}${returnRequest.refundAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            Text(
              'Method: ${_getRefundMethodDisplayName(returnRequest.refundMethod)}',
            ),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(returnRequest.dateCreated)}',
            ),
            SizedBox(height: 8),
            if (returnRequest.notes != null && returnRequest.notes!.isNotEmpty)
              Text(
                'Notes: ${returnRequest.notes!}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment';
      case 'cash':
        return 'Cash';
      case 'credit':
        return 'Credit Card';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
} // Search Order for Return Screen

class SearchOrderForReturnScreen extends StatefulWidget {
  const SearchOrderForReturnScreen({super.key});

  @override
  _SearchOrderForReturnScreenState createState() =>
      _SearchOrderForReturnScreenState();
}

class _SearchOrderForReturnScreenState
    extends State<SearchOrderForReturnScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final TextEditingController _searchController = TextEditingController();
  final List<Order> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Load recent orders initially
    _loadRecentOrders();
  }

  Future<void> _loadRecentOrders() async {
    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final recentOrders = await _posService.getRecentOrders(limit: 20);
      setState(() {
        _searchResults.clear();
        _searchResults.addAll(recentOrders);
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Failed to load recent orders: $e';
        _isSearching = false;
      });
    }
  }

  void _searchOrders(String query) {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _loadRecentOrders();
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _posService.searchOrders(query);
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(results);
          _isSearching = false;
          if (results.isEmpty && query.isNotEmpty) {
            _searchError = 'No orders found for "$query"';
          }
        });
      } catch (e) {
        setState(() {
          _searchError = 'Search failed: $e';
          _isSearching = false;
        });
      }
    });
  }

  void _selectOrder(Order order) {
    Navigator.pop(context, order);
  }

  void _scanOrderBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'return',
    );
    if (barcode != null && barcode.isNotEmpty) {
      _searchController.text = barcode;
      _searchOrders(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Find Order for Return')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by order number...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _searchOrders,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: _scanOrderBarcode,
                  tooltip: 'Scan Order Barcode',
                ),
              ],
            ),
          ),

          // Search Results
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator())
                : _searchError.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(_searchError, textAlign: TextAlign.center),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadRecentOrders,
                          child: Text('Show Recent Orders'),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text('No orders found'),
                        SizedBox(height: 8),
                        Text(
                          'Search for orders or scan order barcode',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final order = _searchResults[index];
                      return OrderCard(
                        order: order,
                        onSelect: () => _selectOrder(order),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class ReturnAnyProductScreen extends StatefulWidget {
  const ReturnAnyProductScreen({super.key});

  @override
  _ReturnAnyProductScreenState createState() => _ReturnAnyProductScreenState();
}

class _ReturnAnyProductScreenState extends State<ReturnAnyProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<ReturnItem> _returnItems = [];
  String _returnReason = 'defective';
  String _refundMethod = 'cash';
  String? _notes;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  bool _isProcessing = false;

  final List<ReturnReason> _returnReasons = [
    ReturnReason(
      id: 'defective',
      name: 'Defective Product',
      description: 'Product not working properly',
    ),
    ReturnReason(
      id: 'wrong_item',
      name: 'Wrong Item Received',
      description: 'Received different product',
    ),
    ReturnReason(
      id: 'damaged',
      name: 'Damaged Product',
      description: 'Product arrived damaged',
    ),
    ReturnReason(
      id: 'not_as_described',
      name: 'Not as Described',
      description: 'Product different from description',
    ),
    ReturnReason(
      id: 'customer_change_mind',
      name: 'Changed Mind',
      description: 'Customer changed their mind',
    ),
    ReturnReason(
      id: 'size_issue',
      name: 'Size Issue',
      description: 'Wrong size ordered',
    ),
    ReturnReason(
      id: 'quality_issue',
      name: 'Quality Issue',
      description: 'Poor quality product',
    ),
    ReturnReason(
      id: 'no_receipt',
      name: 'No Receipt',
      description: 'Return without proof of purchase',
    ),
  ];
  Future<void> _processReturn() async {
    if (_returnItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please add products to return')));
      return;
    }

    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter customer name')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final returnRequest = ReturnRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: 'no_order',
        orderNumber: 'N/A-${DateTime.now().millisecondsSinceEpoch}',
        items: _returnItems,
        reason: _returnReason,
        status: 'completed',
        notes: _notes,
        dateCreated: DateTime.now(),
        refundAmount: _totalRefundAmount,
        refundMethod: _refundMethod,
        customerId: null,
        customerInfo: {
          'name': _customerNameController.text.trim(),
          'phone': _customerPhoneController.text.trim().isEmpty
              ? 'N/A'
              : _customerPhoneController.text.trim(),
          'type': 'walk_in',
          'timestamp': DateTime.now().toIso8601String(),
        },
        isOffline: !_posService.isOnline,
      );

      final result = await _posService.createReturn(returnRequest);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return processed successfully! Refund: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (result.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return saved offline. Will sync when online. Refund: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception(result.error);
      }

      Navigator.of(context).pop();
    } catch (e) {
      print('Error processing return: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process return: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  final List<String> _refundMethods = ['cash', 'store_credit', 'exchange'];

  void _searchAndAddProduct() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (context) => ProductSearchDialog(posService: _posService),
    );

    if (product != null) {
      _showAddProductDialog(product);
    }
  }

  void _scanAndAddProduct() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'return',
    );
    if (barcode != null && barcode.isNotEmpty) {
      try {
        final products = await _posService.searchProductsBySKU(barcode);
        if (products.isNotEmpty) {
          _showAddProductDialog(products.first);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No product found with barcode: $barcode'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddProductDialog(Product product) {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: product.price.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Return ${product.name}'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        image: product.imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(product.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: product.imageUrl == null
                          ? Icon(Icons.shopping_bag, color: Colors.grey)
                          : null,
                    ),
                    title: Text(
                      product.name,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.sku.isNotEmpty) Text('SKU: ${product.sku}'),
                        Text('Current Stock: ${product.stockQuantity}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // Validate quantity doesn't exceed stock
                      final quantity = int.tryParse(value) ?? 0;
                      if (quantity > product.stockQuantity) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Quantity cannot exceed available stock (${product.stockQuantity})',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Refund Price',
                      border: OutlineInputBorder(),
                      prefixText: Constants.CURRENCY_NAME,
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField(
                    initialValue: _returnReason,
                    items: _returnReasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason.id,
                        child: Text(reason.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _returnReason = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Return Reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final quantity = int.tryParse(quantityController.text) ?? 0;
                  final price =
                      double.tryParse(priceController.text) ?? product.price;

                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter valid quantity')),
                    );
                    return;
                  }

                  if (quantity > product.stockQuantity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Quantity cannot exceed available stock'),
                      ),
                    );
                    return;
                  }

                  _addReturnItem(product, quantity, price, _returnReason);
                  Navigator.pop(context);
                },
                child: Text('Add to Return'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addReturnItem(
    Product product,
    int quantity,
    double price,
    String reason,
  ) {
    setState(() {
      _returnItems.add(
        ReturnItem(
          productId: product.id,
          productName: product.name,
          productSku: product.sku,
          quantity: quantity,
          price: price,
          returnReason: reason,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.name} to return'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeReturnItem(int index) {
    setState(() {
      _returnItems.removeAt(index);
    });
  }

  void _updateReturnItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeReturnItem(index);
      return;
    }

    setState(() {
      _returnItems[index] = ReturnItem(
        productId: _returnItems[index].productId,
        productName: _returnItems[index].productName,
        productSku: _returnItems[index].productSku,
        quantity: newQuantity,
        price: _returnItems[index].price,
        returnReason: _returnItems[index].returnReason,
        notes: _returnItems[index].notes,
      );
    });
  }

  double get _totalRefundAmount {
    return _returnItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Widget _buildReturnItemCard(ReturnItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_bag, color: Colors.orange),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (item.productSku.isNotEmpty)
                        Text(
                          'SKU: ${item.productSku}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      Text(
                        '${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)} each',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        'Reason: ${_getReasonName(item.returnReason)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeReturnItem(index),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Quantity:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity - 1),
                        padding: EdgeInsets.zero,
                      ),
                      Text(
                        item.quantity.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity + 1),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Text(
                  '${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Return Products (No Order)'),
        actions: [
          if (_returnItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: () {
                setState(() {
                  _returnItems.clear();
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('All items removed')));
              },
              tooltip: 'Clear All Items',
            ),
        ],
      ),
      body: Column(
        children: [
          // Customer Information
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Enter customer name',
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _customerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: 'Enter phone number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),

          // Add Products Section
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Products to Return',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _searchAndAddProduct,
                          icon: Icon(Icons.search, size: 20),
                          label: Text('Search Product'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scanAndAddProduct,
                          icon: Icon(Icons.qr_code_scanner, size: 20),
                          label: Text('Scan Barcode'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_returnItems.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                      '${_returnItems.length} item${_returnItems.length > 1 ? 's' : ''} added',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 8),

          // Return Items List
          if (_returnItems.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Return Items (${_returnItems.length})',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _returnItems.length,
                itemBuilder: (context, index) {
                  return _buildReturnItemCard(_returnItems[index], index);
                },
              ),
            ),
          ],

          if (_returnItems.isEmpty) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No products added for return',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use search or barcode scan to add products',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _searchAndAddProduct,
                      icon: Icon(Icons.add),
                      label: Text('Add First Product'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Return Details and Action Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Return Details
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField(
                          initialValue: _returnReason,
                          items: _returnReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(reason.name),
                                  Text(
                                    reason.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _returnReason = value!),
                          decoration: InputDecoration(
                            labelText: 'Return Reason',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField(
                          initialValue: _refundMethod,
                          items: _refundMethods.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Text(_getRefundMethodDisplayName(method)),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _refundMethod = value!),
                          decoration: InputDecoration(
                            labelText: 'Refund Method',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                            hintText:
                                'Any additional notes about this return...',
                          ),
                          onChanged: (value) => _notes = value,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Total and Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Refund:', style: TextStyle(fontSize: 16)),
                        Text(
                          '${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: _isProcessing
                          ? ElevatedButton(
                              onPressed: null,
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed:
                                  _returnItems.isNotEmpty &&
                                      _customerNameController.text
                                          .trim()
                                          .isNotEmpty
                                  ? _processReturn
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: Text(
                                'PROCESS RETURN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'cash':
        return 'Cash Refund';
      case 'store_credit':
        return 'Store Credit';
      case 'exchange':
        return 'Exchange Only';
      default:
        return method;
    }
  }

  String _getReasonName(String reasonId) {
    final reason = _returnReasons.firstWhere(
      (reason) => reason.id == reasonId,
      orElse: () => _returnReasons.first,
    );
    return reason.name;
  }
}


class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onSelect;

  const OrderCard({super.key, required this.order, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt, color: Colors.blue),
        ),
        title: Text('Order ${order.number}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy - HH:mm').format(order.dateCreated)),
            Text(
              '${order.lineItems.length} items • ${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onSelect,
      ),
    );
  }
}
