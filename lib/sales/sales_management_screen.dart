import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../constants.dart';
import '../features/auth/auth_base.dart';
import '../main.dart';
import '../modules/auth/providers/auth_provider.dart';

// Sale Model
class Sale {
  final String id;
  final String tenantId;
  final String cashierId;
  final String cashierName;
  final String cashierEmail;
  final List<SaleItem> items;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String paymentMethod;
  final DateTime createdAt;
  final String status;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? notes;

  Sale({
    required this.id,
    required this.tenantId,
    required this.cashierId,
    required this.cashierName,
    required this.cashierEmail,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    required this.status,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.notes,
  });

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse items
    final List<SaleItem> items = [];
    if (data['items'] is List) {
      for (final item in data['items'] as List) {
        items.add(SaleItem.fromMap(Map<String, dynamic>.from(item)));
      }
    } else if (data['lineItems'] is List) {
      for (final item in data['lineItems'] as List) {
        items.add(SaleItem.fromMap(Map<String, dynamic>.from(item)));
      }
    }

    // Parse dates
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      createdAt = DateTime.parse(data['createdAt']);
    } else if (data['dateCreated'] is Timestamp) {
      createdAt = (data['dateCreated'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    // Get customer information from different possible field names
    final customerName = data['customerName']?.toString() ??
        data['customer']?['firstName']?.toString() ??
        data['customer']?['name']?.toString();
    final customerEmail = data['customerEmail']?.toString() ??
        data['customer']?['email']?.toString();
    final customerPhone = data['customerPhone']?.toString() ??
        data['customer']?['phone']?.toString();

    // Calculate totals if not provided
    double subtotal = (data['subtotal'] as num?)?.toDouble() ??
        (data['total'] as num?)?.toDouble() ?? 0.0;
    double taxAmount = (data['taxAmount'] as num?)?.toDouble() ??
        (data['tax'] as num?)?.toDouble() ?? 0.0;
    double totalAmount = (data['totalAmount'] as num?)?.toDouble() ??
        (data['total'] as num?)?.toDouble() ?? 0.0;

    // If totals are not available, calculate from items
    if (subtotal == 0.0 && items.isNotEmpty) {
      subtotal = items.fold(0.0, (sum, item) => sum + item.total);
      totalAmount = subtotal + taxAmount;
    }

    return Sale(
      id: doc.id,
      tenantId: data['tenantId']?.toString() ?? '',
      cashierId: data['cashierId']?.toString() ?? data['userId']?.toString() ?? '',
      cashierName: data['cashierName']?.toString() ?? data['userName']?.toString() ?? 'Unknown Cashier',
      cashierEmail: data['cashierEmail']?.toString() ?? data['userEmail']?.toString() ?? '',
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      paymentMethod: data['paymentMethod']?.toString() ??
          data['payment_method']?.toString() ?? 'cash',
      createdAt: createdAt,
      status: data['status']?.toString() ?? 'completed',
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      notes: data['notes']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'tenantId': tenantId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'cashierEmail': cashierEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      if (customerName != null) 'customerName': customerName,
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (notes != null) 'notes': notes,
    };
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  String get formattedDate => DateFormat('MMM dd, yyyy').format(createdAt);
  String get formattedTime => DateFormat('HH:mm').format(createdAt);
  String get formattedDateTime => DateFormat('MMM dd, yyyy HH:mm').format(createdAt);
}

class SaleItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double total;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    final productName = map['productName']?.toString() ??
        map['name']?.toString() ?? 'Unknown Product';
    final price = (map['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = (map['quantity'] as num?)?.toInt() ?? 0;
    final total = (map['total'] as num?)?.toDouble() ??
        (map['subtotal'] as num?)?.toDouble() ??
        price * quantity;

    return SaleItem(
      productId: map['productId']?.toString() ??
          map['id']?.toString() ?? '',
      productName: productName,
      price: price,
      quantity: quantity,
      total: total,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }
}

// Sales Management Screen
class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  _SalesManagementScreenState createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen>
    with SingleTickerProviderStateMixin {
  final EnhancedPOSService _posService = EnhancedPOSService();
  MyAuthProvider get _authProvider => Provider.of<MyAuthProvider>(context, listen: false);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];
  bool _isLoading = true;
  bool _isOnline = true;
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  String _selectedStatus = 'all';
  String _selectedPaymentMethod = 'all';
  String _selectedCashier = 'all';

  // Statistics
  double _totalRevenue = 0.0;
  int _totalSales = 0;
  double _averageSale = 0.0;
  Map<String, double> _paymentMethodBreakdown = {};
  Map<String, int> _cashierPerformance = {};

  final List<String> _statusOptions = ['all', 'completed', 'pending', 'refunded', 'cancelled'];
  final List<String> _paymentMethods = ['all', 'cash', 'card', 'mobile_money', 'credit', 'store_credit'];

  StreamSubscription<QuerySnapshot>? _salesSubscription;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupConnectivityListener();
    _subscribeToSales();
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

  void _subscribeToSales() {
    final tenantId = _authProvider.currentUser?.tenantId;
    if (tenantId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Subscribe to real-time sales updates
    _salesSubscription = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processSalesSnapshot(snapshot);
    }, onError: (error) {
      print('Error fetching sales: $error');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading sales data'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _processSalesSnapshot(QuerySnapshot snapshot) {
    try {
      final sales = snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();

      if (mounted) {
        setState(() {
          _sales = sales;
          _isLoading = false;
        });
        _calculateStatistics();
        _applyFilters();
      }
    } catch (e) {
      print('Error processing sales data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchSalesData() async {
    setState(() => _isLoading = true);

    try {
      final tenantId = _authProvider.currentUser?.tenantId;
      if (tenantId == null) {
        throw Exception('No tenant ID available');
      }

      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _processSalesSnapshot(snapshot);
    } catch (e) {
      print('Failed to fetch sales data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sales data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _calculateStatistics() async {
    _totalRevenue = _sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    _totalSales = _sales.length;
    _averageSale = _totalSales > 0 ? _totalRevenue / _totalSales : 0.0;

    // Payment method breakdown
    _paymentMethodBreakdown = {};
    for (final sale in _sales) {
      _paymentMethodBreakdown.update(
        sale.paymentMethod,
            (value) => value + sale.totalAmount,
        ifAbsent: () => sale.totalAmount,
      );
    }

    // Cashier performance
    _cashierPerformance = {};
    for (final sale in _sales) {
      _cashierPerformance.update(
        sale.cashierName,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }

  void _setupConnectivityListener() {
    _posService.onlineStatusStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  void _applyFilters() {
    List<Sale> filtered = List.from(_sales);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((sale) =>
      sale.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sale.cashierName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (sale.customerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          sale.items.any((item) => item.productName.toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }

    // Apply status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((sale) => sale.status == _selectedStatus).toList();
    }

    // Apply payment method filter
    if (_selectedPaymentMethod != 'all') {
      filtered = filtered.where((sale) => sale.paymentMethod == _selectedPaymentMethod).toList();
    }

    // Apply cashier filter
    if (_selectedCashier != 'all') {
      filtered = filtered.where((sale) => sale.cashierName == _selectedCashier).toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((sale) =>
      sale.createdAt.isAfter(_selectedDateRange!.start) &&
          sale.createdAt.isBefore(_selectedDateRange!.end)
      ).toList();
    }

    setState(() {
      _filteredSales = filtered;
    });
  }

  Future<void> _refreshData() async {
    if (_isOnline) {
      await _fetchSalesData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offline mode - using cached data'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildFiltersSheet(),
    );
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      currentDate: DateTime.now(),
      saveText: 'Apply',
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = 'all';
      _selectedPaymentMethod = 'all';
      _selectedCashier = 'all';
      _selectedDateRange = null;
    });
    _applyFilters();
  }

  void _viewSaleDetails(Sale sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaleDetailsScreen(sale: sale),
      ),
    );
  }

  void _exportSalesData() {
    // Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildFiltersSheet() {
    final cashiers = _sales.map((sale) => sale.cashierName).toSet().toList();

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: Text('Clear All'),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Status Filter
          Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statusOptions.map((status) {
              return FilterChip(
                label: Text(status == 'all' ? 'All Status' : status),
                selected: _selectedStatus == status,
                onSelected: (selected) {
                  setState(() => _selectedStatus = status);
                  _applyFilters();
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          SizedBox(height: 16),

          // Payment Method Filter
          Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods.map((method) {
              return FilterChip(
                label: Text(method == 'all' ? 'All Methods' : _getPaymentMethodName(method)),
                selected: _selectedPaymentMethod == method,
                onSelected: (selected) {
                  setState(() => _selectedPaymentMethod = method);
                  _applyFilters();
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          SizedBox(height: 16),

          // Cashier Filter
          Text('Cashier', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('All Cashiers'),
                selected: _selectedCashier == 'all',
                onSelected: (selected) {
                  setState(() => _selectedCashier = 'all');
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              ...cashiers.map((cashier) {
                return FilterChip(
                  label: Text(cashier),
                  selected: _selectedCashier == cashier,
                  onSelected: (selected) {
                    setState(() => _selectedCashier = cashier);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
          SizedBox(height: 16),

          // Date Range Filter
          Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showDateRangePicker,
            icon: Icon(Icons.calendar_today, size: 16),
            label: Text(
              _selectedDateRange != null
                  ? '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'
                  : 'Select Date Range',
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'card': return 'Credit Card';
      case 'mobile_money': return 'Mobile Money';
      case 'credit': return 'Credit';
      case 'store_credit': return 'Store Credit';
      default: return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: AnimatedBuilder(
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
                    // Header Section
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue[700]!,
                              Colors.blue[800]!,
                              Colors.indigo[900]!,
                            ],
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
                                        'Sales Management',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Track and manage all sales transactions',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isOnline ? Colors.green[400] : Colors.orange[400],
                                    borderRadius: BorderRadius.circular(20),
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
                                        _isOnline ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                _QuickStatItem(
                                  value: '${_totalSales}',
                                  label: 'Total Sales',
                                  icon: Icons.receipt_long,
                                ),
                                SizedBox(width: 20),
                                _QuickStatItem(
                                  value: '${Constants.CURRENCY_NAME}${_totalRevenue.toStringAsFixed(0)}',
                                  label: 'Total Revenue',
                                  icon: Icons.attach_money,
                                ),
                                SizedBox(width: 20),
                                _QuickStatItem(
                                  value: '${Constants.CURRENCY_NAME}${_averageSale.toStringAsFixed(0)}',
                                  label: 'Average Sale',
                                  icon: Icons.trending_up,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Statistics Section
                    SliverToBoxAdapter(
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
                              title: 'Today\'s Revenue',
                              value: '${Constants.CURRENCY_NAME}${(_totalRevenue * 0.3).toStringAsFixed(0)}',
                              subtitle: '+12.5% from yesterday',
                              icon: Icons.today,
                              color: Colors.green,
                              trend: 12.5,
                            ),
                            _StatCard(
                              title: 'This Week',
                              value: '${Constants.CURRENCY_NAME}${_totalRevenue.toStringAsFixed(0)}',
                              subtitle: '${_totalSales} transactions',
                              icon: Icons.calendar_view_week,
                              color: Colors.blue,
                              trend: 8.3,
                            ),
                            _StatCard(
                              title: 'Top Payment Method',
                              value: _paymentMethodBreakdown.isNotEmpty
                                  ? _getPaymentMethodName(_paymentMethodBreakdown.entries.reduce((a, b) => a.value > b.value ? a : b).key)
                                  : 'N/A',
                              subtitle: 'Most used payment method',
                              icon: Icons.payment,
                              color: Colors.orange,
                              trend: 0.0,
                            ),
                            _StatCard(
                              title: 'Top Cashier',
                              value: _cashierPerformance.isNotEmpty
                                  ? _cashierPerformance.entries.reduce((a, b) => a.value > b.value ? a : b).key
                                  : 'N/A',
                              subtitle: 'Most sales processed',
                              icon: Icons.person,
                              color: Colors.purple,
                              trend: 15.7,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Filters Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      onChanged: (value) {
                                        setState(() => _searchQuery = value);
                                        _applyFilters();
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Search sales, products, cashiers...',
                                        border: InputBorder.none,
                                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.filter_list, color: Colors.blue),
                                    onPressed: _showFiltersDialog,
                                    tooltip: 'Filters',
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.refresh, color: Colors.green),
                                    onPressed: _refreshData,
                                    tooltip: 'Refresh',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            _buildActiveFilters(),
                          ],
                        ),
                      ),
                    ),

                    // Sales List
                    _isLoading
                        ? _buildLoadingState()
                        : _filteredSales.isEmpty
                        ? _buildEmptyState()
                        : _buildSalesList(),

                    // Bottom Padding
                    SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportSalesData,
        icon: Icon(Icons.file_download),
        label: Text('Export'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildActiveFilters() {
    final activeFilters = <Widget>[];

    if (_selectedStatus != 'all') {
      activeFilters.add(
        Chip(
          label: Text('Status: $_selectedStatus'),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() => _selectedStatus = 'all');
            _applyFilters();
          },
        ),
      );
    }

    if (_selectedPaymentMethod != 'all') {
      activeFilters.add(
        Chip(
          label: Text('Payment: ${_getPaymentMethodName(_selectedPaymentMethod)}'),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() => _selectedPaymentMethod = 'all');
            _applyFilters();
          },
        ),
      );
    }

    if (_selectedCashier != 'all') {
      activeFilters.add(
        Chip(
          label: Text('Cashier: $_selectedCashier'),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() => _selectedCashier = 'all');
            _applyFilters();
          },
        ),
      );
    }

    if (_selectedDateRange != null) {
      activeFilters.add(
        Chip(
          label: Text('Date: ${DateFormat('MMM dd').format(_selectedDateRange!.start)}-${DateFormat('MMM dd').format(_selectedDateRange!.end)}'),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() => _selectedDateRange = null);
            _applyFilters();
          },
        ),
      );
    }

    if (activeFilters.isEmpty) return SizedBox();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: activeFilters,
    );
  }

  SliverList _buildSalesList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final sale = _filteredSales[index];
          return _SaleCard(sale: sale, onTap: () => _viewSaleDetails(sale));
        },
        childCount: _filteredSales.length,
      ),
    );
  }

  SliverToBoxAdapter _buildLoadingState() {
    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.blue[700]!),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading Sales Data...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Container(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No Sales Found',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty ||
                    _selectedStatus != 'all' ||
                    _selectedPaymentMethod != 'all' ||
                    _selectedCashier != 'all' ||
                    _selectedDateRange != null
                    ? 'Try adjusting your filters or search terms'
                    : 'Sales will appear here as they are processed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
              SizedBox(height: 20),
              if (_searchQuery.isNotEmpty ||
                  _selectedStatus != 'all' ||
                  _selectedPaymentMethod != 'all' ||
                  _selectedCashier != 'all' ||
                  _selectedDateRange != null)
                ElevatedButton.icon(
                  onPressed: _clearFilters,
                  icon: Icon(Icons.clear_all),
                  label: Text('Clear All Filters'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}

// Sale Card Widget
class _SaleCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;

  const _SaleCard({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sale #${sale.id}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          sale.formattedDateTime,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(sale.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sale.status.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Cashier Info
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.cashierName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          sale.cashierEmail,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Items Summary
              Text(
                'Items (${sale.totalItems}):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              ...sale.items.take(2).map((item) => _buildItemRow(item)),
              if (sale.items.length > 2)
                Text(
                  '+ ${sale.items.length - 2} more items',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              SizedBox(height: 12),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _getPaymentMethodName(sale.paymentMethod),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${Constants.CURRENCY_NAME}${sale.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Customer Info (if available)
              if (sale.customerName != null) ...[
                SizedBox(height: 8),
                Divider(),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Customer: ${sale.customerName!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(SaleItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.productName,
              style: TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${item.quantity} × ${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'refunded':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
        return 'Credit';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
}

// Sale Details Screen
class SaleDetailsScreen extends StatelessWidget {
  final Sale sale;

  const SaleDetailsScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sale Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () {
              // Implement print functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Printing receipt...')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sale Header
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sale #${sale.id}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(sale.status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            sale.status.toUpperCase(),
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
                      sale.formattedDateTime,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Cashier Information
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Processed By',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                      ),
                      title: Text(
                        sale.cashierName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(sale.cashierEmail),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Customer Information (if available)
            if (sale.customerName != null)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: Colors.green[700],
                            size: 24,
                          ),
                        ),
                        title: Text(
                          sale.customerName!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sale.customerEmail != null) Text(sale.customerEmail!),
                            if (sale.customerPhone != null) Text(sale.customerPhone!),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (sale.customerName != null) SizedBox(height: 20),

            // Items List
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items (${sale.totalItems})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...sale.items.map((item) => _buildDetailedItemRow(item)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Payment Summary
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildSummaryRow('Subtotal', sale.subtotal),
                    _buildSummaryRow('Tax Amount', sale.taxAmount),
                    Divider(),
                    _buildSummaryRow('Total Amount', sale.totalAmount, isTotal: true),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Method:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _getPaymentMethodName(sale.paymentMethod),
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Notes (if available)
            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        sale.notes!,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
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

  Widget _buildDetailedItemRow(SaleItem item) {
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
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.shopping_bag,
              size: 20,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Product ID: ${item.productId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Qty: ${item.quantity}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 2),
              Text(
                '${Constants.CURRENCY_NAME}${item.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
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
            ),
          ),
          Text(
            '${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green[700] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'refunded':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
        return 'Credit';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
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
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
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
                if (trend != 0.0)
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
                            color: trend >= 0 ? Colors.green[600] : Colors.red[600],
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
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}