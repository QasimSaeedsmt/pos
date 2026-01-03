import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================================
// MODELS
// ============================================================================

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
  final int pendingOrders;
  final int pendingRestocks;
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
    required this.pendingOrders,
    required this.pendingRestocks,
    required this.pendingReturns,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0.0,
      todayRevenue: 0.0,
      totalSales: 0,
      todaySales: 0,
      totalProducts: 0,
      lowStockProducts: 0,
      totalCustomers: 0,
      todayCustomers: 0,
      averageOrderValue: 0.0,
      conversionRate: 0.0,
      revenueGrowth: 0.0,
      salesGrowth: 0.0,
      todayReturns: 0,
      totalReturns: 0,
      pendingOrders: 0,
      pendingRestocks: 0,
      pendingReturns: 0,
    );
  }

  Map<String, dynamic> toMap() {
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
      'pendingOrders': pendingOrders,
      'pendingRestocks': pendingRestocks,
      'pendingReturns': pendingReturns,
    };
  }

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      totalRevenue: map['totalRevenue']?.toDouble() ?? 0.0,
      todayRevenue: map['todayRevenue']?.toDouble() ?? 0.0,
      totalSales: map['totalSales']?.toInt() ?? 0,
      todaySales: map['todaySales']?.toInt() ?? 0,
      totalProducts: map['totalProducts']?.toInt() ?? 0,
      lowStockProducts: map['lowStockProducts']?.toInt() ?? 0,
      totalCustomers: map['totalCustomers']?.toInt() ?? 0,
      todayCustomers: map['todayCustomers']?.toInt() ?? 0,
      averageOrderValue: map['averageOrderValue']?.toDouble() ?? 0.0,
      conversionRate: map['conversionRate']?.toDouble() ?? 0.0,
      revenueGrowth: map['revenueGrowth']?.toDouble() ?? 0.0,
      salesGrowth: map['salesGrowth']?.toDouble() ?? 0.0,
      todayReturns: map['todayReturns']?.toInt() ?? 0,
      totalReturns: map['totalReturns']?.toInt() ?? 0,
      pendingOrders: map['pendingOrders']?.toInt() ?? 0,
      pendingRestocks: map['pendingRestocks']?.toInt() ?? 0,
      pendingReturns: map['pendingReturns']?.toInt() ?? 0,
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

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'revenue': revenue,
      'orders': orders,
    };
  }

  factory RevenueDataPoint.fromMap(Map<String, dynamic> map) {
    return RevenueDataPoint(
      date: DateTime.parse(map['date']),
      revenue: map['revenue']?.toDouble() ?? 0.0,
      orders: map['orders']?.toInt() ?? 0,
    );
  }
}

class OfflineDashboardData {
  final DashboardStats stats;
  final List<RevenueDataPoint> revenueData;
  final DateTime lastUpdated;
  final String tenantId;

  OfflineDashboardData({
    required this.stats,
    required this.revenueData,
    required this.lastUpdated,
    required this.tenantId,
  });

  Map<String, dynamic> toMap() {
    return {
      'stats': stats.toMap(),
      'revenueData': revenueData.map((point) => point.toMap()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'tenantId': tenantId,
    };
  }

  factory OfflineDashboardData.fromMap(Map<String, dynamic> map) {
    return OfflineDashboardData(
      stats: DashboardStats.fromMap(Map<String, dynamic>.from(map['stats'])),
      revenueData: (map['revenueData'] as List)
          .map((point) => RevenueDataPoint.fromMap(Map<String, dynamic>.from(point)))
          .toList(),
      lastUpdated: DateTime.parse(map['lastUpdated']),
      tenantId: map['tenantId'] ?? '',
    );
  }
}

// ============================================================================
// DASHBOARD REPOSITORY (Database Layer)
// ============================================================================

class DashboardRepository {
  static const String _dashboardBox = 'dashboard_box';
  static const String _statsKey = 'dashboard_stats';
  static const String _revenueDataKey = 'revenue_data';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const String _tenantIdKey = 'tenant_id';

  late final Box<dynamic> _box;

  DashboardRepository();

  Future<void> init() async {
    // NOTE: Prefer calling Hive.initFlutter() once in main()
    // If you must do it here, ensure it's not called multiple times.
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);

    _box = await Hive.openBox<dynamic>(_dashboardBox);
  }

  Future<void> saveDashboardData(OfflineDashboardData data) async {
    await _box.putAll({
      _statsKey: data.stats.toMap(),
      _revenueDataKey: data.revenueData.map((p) => p.toMap()).toList(),
      _cacheTimestampKey: data.lastUpdated.millisecondsSinceEpoch,
      _tenantIdKey: data.tenantId,
    });
  }

  Future<OfflineDashboardData?> getDashboardData(String tenantId) async {
    final statsMap = _box.get(_statsKey);
    final revenueDataList = _box.get(_revenueDataKey);
    final timestamp = _box.get(_cacheTimestampKey);
    final storedTenantId = _box.get(_tenantIdKey);

    if (statsMap == null ||
        revenueDataList == null ||
        timestamp == null ||
        storedTenantId != tenantId) {
      return null;
    }

    try {
      return OfflineDashboardData(
        stats: DashboardStats.fromMap(
          Map<String, dynamic>.from(statsMap as Map),
        ),
        revenueData: (revenueDataList as List)
            .map(
              (point) => RevenueDataPoint.fromMap(
            Map<String, dynamic>.from(point as Map),
          ),
        )
            .toList(),
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(timestamp as int),
        tenantId: storedTenantId as String,
      );
    } catch (e) {
      debugPrint('Error loading cached dashboard data: $e');
      return null;
    }
  }

  Future<void> clearCache() async {
    await _box.clear();
  }

  Future<void> close() async {
    await _box.close();
  }
}

// ============================================================================
// FIREBASE DATA SERVICE
// ============================================================================

class FirebaseDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _tenantId;

  void setTenantId(String tenantId) {
    _tenantId = tenantId;
  }

  CollectionReference get _ordersRef => _firestore
      .collection('tenants')
      .doc(_tenantId)
      .collection('orders');

  CollectionReference get _productsRef => _firestore
      .collection('tenants')
      .doc(_tenantId)
      .collection('products');

  CollectionReference get _customersRef => _firestore
      .collection('tenants')
      .doc(_tenantId)
      .collection('customers');

  CollectionReference get _returnsRef => _firestore
      .collection('tenants')
      .doc(_tenantId)
      .collection('returns');

  CollectionReference get _pendingOrdersRef => _firestore
      .collection('tenants')
      .doc(_tenantId)
      .collection('pending_orders');

  CollectionReference get _pendingRestocksRef => _firestore
      .collection('tenants')
      .doc(_tenantId)
      .collection('pending_restocks');

  CollectionReference get _pendingReturnsRef => _firestore
      .collection('tenants')
      .doc(_tenantId)
      .collection('pending_returns');

  Future<DashboardStats> fetchDashboardStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final yesterdayStart = todayStart.subtract(Duration(days: 1));
    final yesterdayEnd = todayEnd.subtract(Duration(days: 1));

    try {
      // Fetch all data in parallel
      final futures = await Future.wait([
        // Today's orders
        _ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
            .get(),

        // Yesterday's orders
        _ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(yesterdayEnd))
            .get(),

        // All orders
        _ordersRef.get(),

        // Products
        _productsRef.where('status', isEqualTo: 'publish').get(),

        // Customers
        _customersRef.get(),

        // Today's returns
        _returnsRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .get(),

        // All returns
        _returnsRef.get(),

        // Pending orders
        _pendingOrdersRef.where('sync_status', isEqualTo: 'pending').get(),

        // Pending restocks
        _pendingRestocksRef.where('sync_status', isEqualTo: 'pending').get(),

        // Pending returns
        _pendingReturnsRef.where('sync_status', isEqualTo: 'pending').get(),
      ]);

      // Parse results
      final todayOrdersSnapshot = futures[0];
      final yesterdayOrdersSnapshot = futures[1];
      final allOrdersSnapshot = futures[2];
      final productsSnapshot = futures[3];
      final customersSnapshot = futures[4];
      final todayReturnsSnapshot = futures[5];
      final allReturnsSnapshot = futures[6];
      final pendingOrdersSnapshot = futures[7];
      final pendingRestocksSnapshot = futures[8];
      final pendingReturnsSnapshot = futures[9];

      // Calculate today's revenue
      double todayRevenue = 0.0;
      for (final order in todayOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ?? 0.0;
        todayRevenue += total;
      }

      // Calculate yesterday's revenue
      double yesterdayRevenue = 0.0;
      for (final order in yesterdayOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ?? 0.0;
        yesterdayRevenue += total;
      }

      // Calculate total revenue
      double totalRevenue = 0.0;
      for (final order in allOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ?? 0.0;
        totalRevenue += total;
      }

      // Calculate low stock products
      int lowStockCount = 0;
      for (final product in productsSnapshot.docs) {
        final data = product.data() as Map<String, dynamic>;
        final stockQuantity = _safeGetInt(data, 'stockQuantity') ??
            _safeGetInt(data, 'stock') ?? 0;
        if (stockQuantity <= 10) {
          lowStockCount++;
        }
      }

      // Today's unique customers
      final todayCustomerIds = <String>{};
      for (final order in todayOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final customerId = data['customerId']?.toString();
        if (customerId != null && customerId.isNotEmpty && customerId != 'null') {
          todayCustomerIds.add(customerId);
        }
      }

      // Calculate derived metrics
      final averageOrderValue = allOrdersSnapshot.docs.isNotEmpty
          ? totalRevenue / allOrdersSnapshot.docs.length
          : 0.0;

      final conversionRate = customersSnapshot.docs.isNotEmpty
          ? (allOrdersSnapshot.docs.length / customersSnapshot.docs.length * 100)
          .clamp(0.0, 100.0)
          : 0.0;

      final revenueGrowth = _calculateGrowthPercentage(todayRevenue, yesterdayRevenue);
      final salesGrowth = _calculateGrowthPercentage(
        todayOrdersSnapshot.docs.length.toDouble(),
        yesterdayOrdersSnapshot.docs.length.toDouble(),
      );

      return DashboardStats(
        totalRevenue: totalRevenue,
        todayRevenue: todayRevenue,
        totalSales: allOrdersSnapshot.docs.length,
        todaySales: todayOrdersSnapshot.docs.length,
        totalProducts: productsSnapshot.docs.length,
        lowStockProducts: lowStockCount,
        totalCustomers: customersSnapshot.docs.length,
        todayCustomers: todayCustomerIds.length,
        averageOrderValue: averageOrderValue,
        conversionRate: conversionRate,
        revenueGrowth: revenueGrowth,
        salesGrowth: salesGrowth,
        todayReturns: todayReturnsSnapshot.docs.length,
        totalReturns: allReturnsSnapshot.docs.length,
        pendingOrders: pendingOrdersSnapshot.docs.length,
        pendingRestocks: pendingRestocksSnapshot.docs.length,
        pendingReturns: pendingReturnsSnapshot.docs.length,
      );
    } catch (e) {
      debugPrint('Error fetching dashboard stats from Firebase: $e');
      throw Exception('Failed to fetch dashboard data: $e');
    }
  }

  Future<List<RevenueDataPoint>> fetchRevenueData() async {
    final now = DateTime.now();
    final List<RevenueDataPoint> revenueData = [];

    try {
      for (int i = 6; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day - i);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        final ordersSnapshot = await _ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();

        double dayRevenue = 0.0;
        int dayOrders = 0;

        for (final order in ordersSnapshot.docs) {
          final data = order.data() as Map<String, dynamic>;
          final total = _safeGetDouble(data, 'total') ??
              _safeGetDouble(data, 'totalAmount') ?? 0.0;
          dayRevenue += total;
          dayOrders++;
        }

        revenueData.add(RevenueDataPoint(
          date: date,
          revenue: dayRevenue,
          orders: dayOrders,
        ));
      }

      return revenueData;
    } catch (e) {
      debugPrint('Error fetching revenue data: $e');
      return List.generate(7, (index) {
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        return RevenueDataPoint(date: date, revenue: 0.0, orders: 0);
      });
    }
  }

  double? _safeGetDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;

    // Handle various number types
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    // Handle string representations
    if (value is String) {
      // Try to parse as double
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;

      // Try removing currency symbols
      final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(cleaned);
    }

    // For any other type, try to convert to string first
    try {
      return double.tryParse(value.toString());
    } catch (e) {
      debugPrint('Error converting $value to double: $e');
      return null;
    }
  }

  int? _safeGetInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;

    // Handle various integer types
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();

    // Handle string representations
    if (value is String) {
      // Try to parse as int
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;

      // Try parsing as double first, then convert to int
      final doubleParsed = double.tryParse(value);
      if (doubleParsed != null) return doubleParsed.toInt();
    }

    // For any other type, try to convert to string first
    try {
      return int.tryParse(value.toString());
    } catch (e) {
      debugPrint('Error converting $value to int: $e');
      return null;
    }
  }

  double _calculateGrowthPercentage(double today, double yesterday) {
    if (yesterday == 0) return today > 0 ? 100.0 : 0.0;
    return ((today - yesterday) / yesterday * 100);
  }
}

// ============================================================================
// DASHBOARD VIEW MODEL (Business Logic)
// ============================================================================

class DashboardViewModel extends ChangeNotifier {
  final DashboardRepository _repository;
  final FirebaseDashboardService _firebaseService;
  final Connectivity _connectivity = Connectivity();

  DashboardStats _stats = DashboardStats.empty();
  List<RevenueDataPoint> _revenueData = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isOnline = true;
  bool _showingCachedData = false;
  String? _errorMessage;

  DashboardStats get stats => _stats;
  List<RevenueDataPoint> get revenueData => _revenueData;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isOnline => _isOnline;
  bool get showingCachedData => _showingCachedData;
  String? get errorMessage => _errorMessage;

  DashboardViewModel({
    required DashboardRepository repository,
    required FirebaseDashboardService firebaseService,
  }) : _repository = repository, _firebaseService = firebaseService {
    _init();
  }

  Future<void> _init() async {
    await _repository.init();
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        // Came back online, refresh data
        loadDashboardData();
      }

      notifyListeners();
    });
  }

  Future<void> loadDashboardData({String? tenantId, bool forceRefresh = false}) async {
    if (tenantId == null || tenantId.isEmpty) {
      _errorMessage = 'Tenant ID is required';
      notifyListeners();
      return;
    }

    _firebaseService.setTenantId(tenantId);

    if (!forceRefresh && _isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasNetwork = connectivityResult != ConnectivityResult.none;

      if (!hasNetwork) {
        // Offline mode: load from cache
        await _loadFromCache(tenantId);
      } else {
        // Online mode: try to fetch fresh data
        await _loadFromFirebase(tenantId);
      }
    } catch (e) {
      _errorMessage = 'Failed to load dashboard data: $e';
      debugPrint('Dashboard load error: $e');

      // Fallback to cache if available
      final cachedData = await _repository.getDashboardData(tenantId);
      if (cachedData != null) {
        _stats = cachedData.stats;
        _revenueData = cachedData.revenueData;
        _showingCachedData = true;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromCache(String tenantId) async {
    final cachedData = await _repository.getDashboardData(tenantId);

    if (cachedData != null) {
      _stats = cachedData.stats;
      _revenueData = cachedData.revenueData;
      _showingCachedData = true;
      _isOnline = false;
    } else {
      _errorMessage = 'No cached data available. Please connect to the internet.';
      _stats = DashboardStats.empty();
      _revenueData = [];
    }
  }

  Future<void> _loadFromFirebase(String tenantId) async {
    try {
      // Fetch fresh data with timeout
      final statsFuture = _firebaseService.fetchDashboardStats();
      final revenueFuture = _firebaseService.fetchRevenueData();

      final results = await Future.wait([statsFuture, revenueFuture])
          .timeout(Duration(seconds: 15));

      _stats = results[0] as DashboardStats;
      _revenueData = results[1] as List<RevenueDataPoint>;
      _showingCachedData = false;
      _isOnline = true;

      // Cache the fresh data
      final offlineData = OfflineDashboardData(
        stats: _stats,
        revenueData: _revenueData,
        lastUpdated: DateTime.now(),
        tenantId: tenantId,
      );

      await _repository.saveDashboardData(offlineData);
    } on TimeoutException {
      // Timeout: try to load from cache
      await _loadFromCache(tenantId);
      _errorMessage = 'Connection timeout. Showing cached data.';
    } catch (e) {
      // Firebase error: try to load from cache
      await _loadFromCache(tenantId);
      _errorMessage = 'Network error. Showing cached data.';
    }
  }

  Future<void> refreshData(String tenantId) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    await loadDashboardData(tenantId: tenantId, forceRefresh: true);

    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> clearCache() async {
    await _repository.clearCache();
    _stats = DashboardStats.empty();
    _revenueData = [];
    _showingCachedData = false;
    notifyListeners();
  }

//   @override
//   void dispose() {
//     _repository.close();
//     super.dispose();
//   }
}

// ============================================================================
// DASHBOARD UI COMPONENTS
// ============================================================================

class DashboardHeader extends StatelessWidget {
  final String businessName;
  final bool isOnline;
  final bool showingCachedData;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const DashboardHeader({
    super.key,
    required this.businessName,
    required this.isOnline,
    required this.showingCachedData,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.blue.shade900],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_getGreeting()},',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    businessName.isNotEmpty ? businessName : 'Your Business',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Business Dashboard',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // Status and refresh button
              Column(
                children: [
                  _buildStatusIndicator(),
                  const SizedBox(height: 8),
                  if (isRefreshing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: onRefresh,
                      tooltip: 'Refresh Data',
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quick stats bar
          _buildQuickStatsBar(context),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    String statusText;
    IconData? statusIcon;

    if (!isOnline) {
      statusColor = Colors.orange;
      statusText = 'Offline';
      statusIcon = Icons.wifi_off;
    } else if (showingCachedData) {
      statusColor = Colors.yellow.shade700;
      statusText = 'Cached';
      statusIcon = Icons.cloud_download;
    } else {
      statusColor = Colors.green;
      statusText = 'Live';
      statusIcon = Icons.wifi;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          ...[
          const SizedBox(width: 4),
          Icon(statusIcon, size: 12, color: Colors.white),
        ],
        ],
      ),
    );
  }

  Widget _buildQuickStatsBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickStatItem(
            icon: Icons.shopping_cart,
            label: 'Online',
            value: isOnline ? 'Yes' : 'No',
          ),
          _QuickStatItem(
            icon: Icons.cloud,
            label: 'Data',
            value: showingCachedData ? 'Cached' : 'Live',
          ),
          _QuickStatItem(
            icon: Icons.update,
            label: 'Last Sync',
            value: _getLastSyncTime(),
          ),
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

  String _getLastSyncTime() {
    return 'Now';
  }
}

class _QuickStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QuickStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}

class StatsGrid extends StatelessWidget {
  final DashboardStats stats;

  const StatsGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
        children: [
          _StatCard(
            title: 'Total Revenue',
            value: '\$${stats.totalRevenue.toStringAsFixed(0)}',
            subtitle: '\$${stats.todayRevenue.toStringAsFixed(0)} today',
            icon: Icons.attach_money,
            color: Colors.green,
            trend: stats.revenueGrowth,
          ),
          _StatCard(
            title: 'Total Sales',
            value: stats.totalSales.toString(),
            subtitle: '${stats.todaySales} today',
            icon: Icons.shopping_cart,
            color: Colors.blue,
            trend: stats.salesGrowth,
          ),
          _StatCard(
            title: 'Customers',
            value: stats.totalCustomers.toString(),
            subtitle: '${stats.todayCustomers} today',
            icon: Icons.people,
            color: Colors.purple,
            trend: 0.0,
          ),
          _StatCard(
            title: 'Products',
            value: stats.totalProducts.toString(),
            subtitle: '${stats.lowStockProducts} low stock',
            icon: Icons.inventory,
            color: Colors.orange,
            trend: 0.0,
          ),
        ],
      ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with icon and trend
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const Spacer(),
              if (trend != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: trend >= 0
                        ? Colors.green.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: trend >= 0
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trend.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: trend >= 0
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class RevenueChart extends StatelessWidget {
  final List<RevenueDataPoint> revenueData;

  const RevenueChart({super.key, required this.revenueData});

  @override
  Widget build(BuildContext context) {
    final weeklyGrowth = _calculateWeeklyGrowth();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Revenue Overview (Last 7 Days)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: weeklyGrowth >= 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${weeklyGrowth >= 0 ? '+' : ''}${weeklyGrowth.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: weeklyGrowth >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: const TextStyle(fontSize: 12),
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.compactCurrency(symbol: '\$'),
                majorGridLines: MajorGridLines(
                  width: 1,
                  color: Colors.grey.shade100,
                ),
                labelStyle: const TextStyle(fontSize: 12),
              ),
              series: <CartesianSeries>[
                ColumnSeries<RevenueDataPoint, String>(
                  dataSource: revenueData,
                  xValueMapper: (RevenueDataPoint data, _) =>
                      DateFormat('E').format(data.date),
                  yValueMapper: (RevenueDataPoint data, _) => data.revenue,
                  color: Colors.blueAccent.shade400,
                  width: 0.6,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateWeeklyGrowth() {
    if (revenueData.length < 2) return 0.0;

    final firstHalf = revenueData
        .take(3)
        .fold(0.0, (sum, data) => sum + data.revenue);
    final secondHalf = revenueData
        .skip(3)
        .fold(0.0, (sum, data) => sum + data.revenue);

    if (firstHalf == 0) return secondHalf > 0 ? 100.0 : 0.0;
    return ((secondHalf - firstHalf) / firstHalf * 100);
  }
}

class PendingActionsCard extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback onSyncPressed;

  const PendingActionsCard({
    super.key,
    required this.stats,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasPendingActions = stats.pendingOrders > 0 ||
        stats.pendingRestocks > 0 ||
        stats.pendingReturns > 0;

    if (!hasPendingActions) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Pending Sync Actions',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (stats.pendingOrders > 0)
            _PendingActionItem(
              icon: Icons.shopping_cart,
              label: 'Orders',
              count: stats.pendingOrders,
              color: Colors.blue,
            ),

          if (stats.pendingRestocks > 0)
            _PendingActionItem(
              icon: Icons.inventory,
              label: 'Restocks',
              count: stats.pendingRestocks,
              color: Colors.green,
            ),

          if (stats.pendingReturns > 0)
            _PendingActionItem(
              icon: Icons.assignment_return,
              label: 'Returns',
              count: stats.pendingReturns,
              color: Colors.red,
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSyncPressed,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _PendingActionItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MAIN DASHBOARD SCREEN
// ============================================================================

// ============================================================================
// MAIN DASHBOARD SCREEN
// ============================================================================

class NewDashboardScreen extends StatefulWidget {
  const NewDashboardScreen({super.key});

  @override
  State<NewDashboardScreen> createState() => _NewDashboardScreenState();
}

class _NewDashboardScreenState extends State<NewDashboardScreen> {
  late DashboardViewModel _viewModel;
  bool _initialDataLoaded = false;
  bool _isRefreshing = false; // For manual refresh debouncing

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardViewModel(
      repository: DashboardRepository(),
      firebaseService: FirebaseDashboardService(),
    );

    // Load initial data once when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    if (!_initialDataLoaded && mounted) {
      final tenantId = _getCurrentTenantId();
      if (tenantId.isNotEmpty) {
        _viewModel.loadDashboardData(tenantId: tenantId);
        _initialDataLoaded = true;
      }
    }
  }

  Future<void> _safeRefresh(DashboardViewModel viewModel) async {
    if (_isRefreshing || !mounted) return;

    _isRefreshing = true;
    try {
      final tenantId = _getCurrentTenantId();
      if (tenantId.isNotEmpty) {
        await viewModel.refreshData(tenantId);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _getCurrentTenantId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    }
    return '';
  }

  String _getBusinessName() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? 'Your Business';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<DashboardViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: _buildBody(viewModel),
          );
        },
      ),
    );
  }

  Widget _buildBody(DashboardViewModel viewModel) {
    // Show loading only for initial load, not for refreshes
    if (viewModel.isLoading && !_initialDataLoaded) {
      return _buildLoadingView();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _safeRefresh(viewModel);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: DashboardHeader(
              businessName: _getBusinessName(),
              isOnline: viewModel.isOnline,
              showingCachedData: viewModel.showingCachedData,
              isRefreshing: viewModel.isRefreshing,
              onRefresh: () => _safeRefresh(viewModel),
            ),
          ),

          // Error message if any
          if (viewModel.errorMessage != null)
            SliverToBoxAdapter(
              child: _buildErrorMessage(viewModel.errorMessage!),
            ),

          // Stats Grid
          SliverToBoxAdapter(
            child: StatsGrid(stats: viewModel.stats),
          ),

          // Revenue Chart
          SliverToBoxAdapter(
            child: RevenueChart(revenueData: viewModel.revenueData),
          ),

          // Pending Actions
          SliverToBoxAdapter(
            child: PendingActionsCard(
              stats: viewModel.stats,
              onSyncPressed: () => _safeRefresh(viewModel),
            ),
          ),

          // Additional Stats
          SliverToBoxAdapter(
            child: _buildAdditionalStats(viewModel.stats),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 20),
          Text(
            'Loading Dashboard Data...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalStats(DashboardStats stats) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Average Order Value',
            '\$${stats.averageOrderValue.toStringAsFixed(2)}',
          ),
          _buildMetricRow(
            'Conversion Rate',
            '${stats.conversionRate.toStringAsFixed(1)}%',
          ),
          _buildMetricRow(
            'Returns Today',
            stats.todayReturns.toString(),
          ),
          _buildMetricRow(
            'Total Returns',
            stats.totalReturns.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // @override
  // void dispose() {
  //   _viewModel.dispose();
  //   super.dispose();
  // }
}