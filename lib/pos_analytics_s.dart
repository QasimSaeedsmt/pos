// lib/features/analytics/pos_analytics_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../core/models/app_order_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/return_request.dart';
import '../../core/overlay_manager.dart';
import '../../theme_utils.dart';
import 'features/connectivityBase/local_db_base.dart';


// ============================================================================
// Analytics Data Models
// ============================================================================

class AnalyticsData {
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;
  final double totalTax;
  final double totalDiscounts;
  final double totalRefunds;
  final double netRevenue;
  final Map<String, double> paymentMethodBreakdown;
  final List<TopProduct> topProductsByQuantity;
  final List<TopProduct> topProductsByRevenue;
  final List<DailyRevenue> dailyRevenue;
  final DateTime startDate;
  final DateTime endDate;

  AnalyticsData({
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.totalTax,
    required this.totalDiscounts,
    required this.totalRefunds,
    required this.netRevenue,
    required this.paymentMethodBreakdown,
    required this.topProductsByQuantity,
    required this.topProductsByRevenue,
    required this.dailyRevenue,
    required this.startDate,
    required this.endDate,
  });

  bool get hasData => totalOrders > 0;
}

class TopProduct {
  final String productId;
  final String productName;
  final String productSku;
  final int quantitySold;
  final double revenue;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantitySold,
    required this.revenue,
  });
}

class DailyRevenue {
  final DateTime date;
  final double revenue;
  final int orders;

  DailyRevenue({
    required this.date,
    required this.revenue,
    required this.orders,
  });
}

class ChartData {
  final String x;
  final double y;

  ChartData(this.x, this.y);
}

// ============================================================================
// Analytics Service
// ============================================================================

class POSAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDatabase _localDb = LocalDatabase();
  final String _tenantId;

  POSAnalyticsService({required String tenantId}) : _tenantId = tenantId;

  String get _ordersCollectionPath => 'tenants/$_tenantId/orders';

  Future<bool> get _isOnline async {
    try {
      await _firestore.collection('tenants').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<AnalyticsData> getAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final isOnline = await _isOnline;

    if (isOnline) {
      return await _getAnalyticsFromFirestore(startDate, endDate);
    } else {
      return await _getAnalyticsFromCache(startDate, endDate);
    }
  }

  Future<AnalyticsData> _getAnalyticsFromFirestore(
      DateTime startDate,
      DateTime endDate,
      ) async {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final QuerySnapshot ordersSnapshot = await _firestore
        .collection(_ordersCollectionPath)
        .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final List<AppOrder> orders = ordersSnapshot.docs
        .map((doc) => AppOrder.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    final List<ReturnRequest> returns = await _getReturnsForPeriod(startDate, endOfDay);

    return _calculateAnalytics(orders, returns, startDate, endDate);
  }

  Future<AnalyticsData> _getAnalyticsFromCache(
      DateTime startDate,
      DateTime endDate,
      ) async {
    final pendingOrders = await _localDb.getPendingOrders();
    final List<AppOrder> orders = [];

    for (final pendingOrder in pendingOrders) {
      final createdAt = DateTime.parse(pendingOrder['created_at']);
      if (createdAt.isAfter(startDate) && createdAt.isBefore(endDate.add(const Duration(days: 1)))) {
        final orderData = pendingOrder['order_data'] as Map<String, dynamic>;
        final order = AppOrder(
          id: pendingOrder['id'].toString(),
          number: 'OFFLINE-${pendingOrder['id']}',
          dateCreated: createdAt,
          total: (orderData['total'] as num?)?.toDouble() ?? 0.0,
          lineItems: orderData['line_items'] ?? [],
          customerId: pendingOrder['customer_data']?['customerId'],
          customerName: pendingOrder['customer_data']?['firstName'],
        );
        orders.add(order);
      }
    }

    final pendingReturns = await _localDb.getPendingReturns();
    final List<ReturnRequest> returns = [];

    for (final pendingReturn in pendingReturns) {
      final returnDate = DateTime.parse(pendingReturn['created_at'] ?? DateTime.now().toIso8601String());
      if (returnDate.isAfter(startDate) && returnDate.isBefore(endDate.add(const Duration(days: 1)))) {
        returns.add(ReturnRequest.fromLocalMap(pendingReturn));
      }
    }

    return _calculateAnalytics(orders, returns, startDate, endDate);
  }

  Future<List<ReturnRequest>> _getReturnsForPeriod(DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot returnsSnapshot = await _firestore
          .collection('tenants')
          .doc(_tenantId)
          .collection('returns')
          .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return returnsSnapshot.docs
          .map((doc) => ReturnRequest.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  AnalyticsData _calculateAnalytics(
      List<AppOrder> orders,
      List<ReturnRequest> returns,
      DateTime startDate,
      DateTime endDate,
      ) {
    double totalRevenue = 0.0;
    double totalTax = 0.0;
    double totalDiscounts = 0.0;
    final Map<String, double> paymentMethodBreakdown = {
      'cash': 0.0,
      'easypaisa/bank transfer': 0.0,
      'credit': 0.0,
    };
    final Map<String, TopProductData> productData = {};
    final Map<String, DailyRevenueData> dailyData = {};

    for (final order in orders) {
      totalRevenue += order.total;
      totalTax += order.calculateTaxAmount();
      totalDiscounts += order.calculateTotalDiscount();

      final paymentMethod = _extractPaymentMethod(order);
      paymentMethodBreakdown[paymentMethod] = (paymentMethodBreakdown[paymentMethod] ?? 0.0) + order.total;

      final orderDate = DateTime(order.dateCreated.year, order.dateCreated.month, order.dateCreated.day);
      final dateKey = DateFormat('yyyy-MM-dd').format(orderDate);
      dailyData.putIfAbsent(dateKey, () => DailyRevenueData(date: orderDate));
      dailyData[dateKey]!.revenue += order.total;
      dailyData[dateKey]!.orders += 1;

      for (final item in order.lineItems) {
        if (item is Map<String, dynamic>) {
          final productId = item['product_id']?.toString() ?? item['productId']?.toString() ?? '';
          final productName = item['product_name']?.toString() ?? item['productName']?.toString() ?? 'Unknown';
          final productSku = item['product_sku']?.toString() ?? item['sku']?.toString() ?? '';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final itemTotal = quantity * price;

          productData.putIfAbsent(productId, () => TopProductData(
            productId: productId,
            productName: productName,
            productSku: productSku,
          ));
          productData[productId]!.quantitySold += quantity;
          productData[productId]!.revenue += itemTotal;
        }
      }
    }

    double totalRefunds = 0.0;
    for (final returnReq in returns) {
      totalRefunds += returnReq.refundAmount;
    }

    final double netRevenue = totalRevenue - totalRefunds;
    final double averageOrderValue = orders.isEmpty ? 0.0 : totalRevenue / orders.length;

    final List<TopProduct> topProductsByQuantity = productData.values
        .map((d) => TopProduct(
      productId: d.productId,
      productName: d.productName,
      productSku: d.productSku,
      quantitySold: d.quantitySold,
      revenue: d.revenue,
    ))
        .toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    final List<TopProduct> topProductsByRevenue = productData.values
        .map((d) => TopProduct(
      productId: d.productId,
      productName: d.productName,
      productSku: d.productSku,
      quantitySold: d.quantitySold,
      revenue: d.revenue,
    ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final List<DailyRevenue> dailyRevenue = [];
    for (var i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final currentDate = DateTime(startDate.year, startDate.month, startDate.day + i);
      final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      if (dailyData.containsKey(dateKey)) {
        dailyRevenue.add(dailyData[dateKey]!.toDailyRevenue());
      } else {
        dailyRevenue.add(DailyRevenue(date: currentDate, revenue: 0.0, orders: 0));
      }
    }

    return AnalyticsData(
      totalRevenue: totalRevenue,
      totalOrders: orders.length,
      averageOrderValue: averageOrderValue,
      totalTax: totalTax,
      totalDiscounts: totalDiscounts,
      totalRefunds: totalRefunds,
      netRevenue: netRevenue,
      paymentMethodBreakdown: paymentMethodBreakdown,
      topProductsByQuantity: topProductsByQuantity.take(5).toList(),
      topProductsByRevenue: topProductsByRevenue.take(5).toList(),
      dailyRevenue: dailyRevenue,
      startDate: startDate,
      endDate: endDate,
    );
  }

  String _extractPaymentMethod(AppOrder order) {
    final enhancedData = order.extractEnhancedData();
    if (enhancedData.containsKey('paymentMethod')) {
      final method = enhancedData['paymentMethod'].toString().toLowerCase();
      if (method.contains('cash')) return 'cash';
      if (method.contains('easypaisa') || method.contains('bank')) return 'easypaisa/bank transfer';
      if (method.contains('credit')) return 'credit';
    }

    if (order.customerData != null && order.customerData!.containsKey('enhancedData')) {
      final enhanced = order.customerData!['enhancedData'] as Map<String, dynamic>?;
      if (enhanced != null && enhanced.containsKey('paymentMethod')) {
        final method = enhanced['paymentMethod'].toString().toLowerCase();
        if (method.contains('cash')) return 'cash';
        if (method.contains('easypaisa') || method.contains('bank')) return 'easypaisa/bank transfer';
        if (method.contains('credit')) return 'credit';
      }
    }

    return 'cash';
  }

  Future<void> cacheAnalytics(AnalyticsData data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'analytics_cache_${DateFormat('yyyy-MM-dd').format(data.startDate)}_${DateFormat('yyyy-MM-dd').format(data.endDate)}';

    final cacheData = {
      'totalRevenue': data.totalRevenue,
      'totalOrders': data.totalOrders,
      'averageOrderValue': data.averageOrderValue,
      'totalTax': data.totalTax,
      'totalDiscounts': data.totalDiscounts,
      'totalRefunds': data.totalRefunds,
      'netRevenue': data.netRevenue,
      'paymentMethodBreakdown': data.paymentMethodBreakdown,
      'startDate': data.startDate.toIso8601String(),
      'endDate': data.endDate.toIso8601String(),
    };

    await prefs.setString(cacheKey, cacheData.toString());
  }
}

class TopProductData {
  final String productId;
  final String productName;
  final String productSku;
  int quantitySold;
  double revenue;

  TopProductData({
    required this.productId,
    required this.productName,
    required this.productSku,
    this.quantitySold = 0,
    this.revenue = 0.0,
  });
}

class DailyRevenueData {
  final DateTime date;
  double revenue;
  int orders;

  DailyRevenueData({
    required this.date,
    this.revenue = 0.0,
    this.orders = 0,
  });

  DailyRevenue toDailyRevenue() => DailyRevenue(date: date, revenue: revenue, orders: orders);
}

// ============================================================================
// Time Period Selector
// ============================================================================

enum TimePeriod {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  custom,
}

extension TimePeriodExtension on TimePeriod {
  String get displayName {
    switch (this) {
      case TimePeriod.today:
        return 'Today';
      case TimePeriod.yesterday:
        return 'Yesterday';
      case TimePeriod.last7Days:
        return 'Last 7 Days';
      case TimePeriod.last30Days:
        return 'Last 30 Days';
      case TimePeriod.thisMonth:
        return 'This Month';
      case TimePeriod.custom:
        return 'Custom Range';
    }
  }

  (DateTime, DateTime) getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case TimePeriod.today:
        return (today, today);
      case TimePeriod.yesterday:
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        return (yesterday, yesterday);
      case TimePeriod.last7Days:
        return (DateTime(now.year, now.month, now.day - 6), today);
      case TimePeriod.last30Days:
        return (DateTime(now.year, now.month, now.day - 29), today);
      case TimePeriod.thisMonth:
        return (DateTime(now.year, now.month, 1), today);
      case TimePeriod.custom:
        return (today, today);
    }
  }
}

// ============================================================================
// Main Analytics Screen
// ============================================================================

class POSAnalyticsScreen extends StatefulWidget {
  final String tenantId;

  const POSAnalyticsScreen({
    super.key,
    required this.tenantId,
  });

  @override
  State<POSAnalyticsScreen> createState() => _POSAnalyticsScreenState();
}

class _POSAnalyticsScreenState extends State<POSAnalyticsScreen> {
  late POSAnalyticsService _analyticsService;

  TimePeriod _selectedPeriod = TimePeriod.today;
  DateTime _customStartDate = DateTime.now();
  DateTime _customEndDate = DateTime.now();

  AnalyticsData? _analyticsData;
  bool _isLoading = false;
  String? _errorMessage;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _analyticsService = POSAnalyticsService(tenantId: widget.tenantId);
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DateTime startDate, endDate;

      if (_selectedPeriod == TimePeriod.custom) {
        startDate = _customStartDate;
        endDate = _customEndDate;
      } else {
        final range = _selectedPeriod.getDateRange();
        startDate = range.$1;
        endDate = range.$2;
      }

      final data = await _analyticsService.getAnalytics(
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });

      await _analyticsService.cacheAnalytics(data);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load analytics: $e';
        _isLoading = false;
      });
      OverlayManager.showError(context, _errorMessage!);
    }
  }

  void _refreshData() {
    _loadAnalytics();
  }

  void _showTimePeriodSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Time Period',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...TimePeriod.values.map((period) => ListTile(
              leading: Radio<TimePeriod>(
                value: period,
                groupValue: _selectedPeriod,
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                  });
                  Navigator.pop(context);
                  _loadAnalytics();
                },
              ),
              title: Text(period.displayName),
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                });
                Navigator.pop(context);
                if (period != TimePeriod.custom) {
                  _loadAnalytics();
                } else {
                  _showCustomDatePicker();
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _customStartDate,
        end: _customEndDate,
      ),
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedPeriod = TimePeriod.custom;
      });
      _loadAnalytics();
    }
  }

  Future<void> _exportToPDF() async {
    if (_analyticsData == null || !_analyticsData!.hasData) {
      OverlayManager.showToast(
        context: context,
        message: 'No data to export',
        backgroundColor: Colors.orange,
      );
      return;
    }

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader(),
                _buildPdfSummary(),
                _buildPdfPaymentBreakdown(),
                _buildPdfTopProducts(),
                _buildPdfDailyRevenue(),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      OverlayManager.showToast(
        context: context,
        message: 'PDF exported successfully',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      OverlayManager.showError(context, 'Failed to export PDF: $e');
      debugPrint('PDF Export Error: $e');
    }
  }

  pw.Widget _buildPdfHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'POS Analytics Report',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Period: ${DateFormat('MMM dd, yyyy').format(_analyticsData!.startDate)} - ${DateFormat('MMM dd, yyyy').format(_analyticsData!.endDate)}',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
        ),
        pw.Text(
          'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfSummary() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Summary',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
              ],
            ),
            _buildPdfSummaryRow('Total Revenue', '${Constants.CURRENCY_NAME}${_analyticsData!.totalRevenue.toStringAsFixed(2)}'),
            _buildPdfSummaryRow('Total Orders', _analyticsData!.totalOrders.toString()),
            _buildPdfSummaryRow('Average Order Value', '${Constants.CURRENCY_NAME}${_analyticsData!.averageOrderValue.toStringAsFixed(2)}'),
            _buildPdfSummaryRow('Total Tax', '${Constants.CURRENCY_NAME}${_analyticsData!.totalTax.toStringAsFixed(2)}'),
            _buildPdfSummaryRow('Total Discounts', '${Constants.CURRENCY_NAME}${_analyticsData!.totalDiscounts.toStringAsFixed(2)}'),
            _buildPdfSummaryRow('Total Refunds', '${Constants.CURRENCY_NAME}${_analyticsData!.totalRefunds.toStringAsFixed(2)}'),
            _buildPdfSummaryRow('Net Revenue', '${Constants.CURRENCY_NAME}${_analyticsData!.netRevenue.toStringAsFixed(2)}'),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.TableRow _buildPdfSummaryRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(child: pw.Text(label), padding: pw.EdgeInsets.all(6)),
        pw.Padding(child: pw.Text(value), padding: pw.EdgeInsets.all(6)),
      ],
    );
  }

  pw.Widget _buildPdfPaymentBreakdown() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Payment Methods',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(child: pw.Text('Method', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Percentage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
              ],
            ),
            ..._analyticsData!.paymentMethodBreakdown.entries.map((entry) {
              final percentage = _analyticsData!.totalRevenue > 0
                  ? (entry.value / _analyticsData!.totalRevenue * 100).toStringAsFixed(1)
                  : '0.0';
              return pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(_capitalize(entry.key)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${entry.value.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('$percentage%'), padding: pw.EdgeInsets.all(6)),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfTopProducts() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Products by Quantity',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
              ],
            ),
            ..._analyticsData!.topProductsByQuantity.map((product) => pw.TableRow(
              children: [
                pw.Padding(child: pw.Text(product.productName), padding: pw.EdgeInsets.all(6)),
                pw.Padding(child: pw.Text(product.quantitySold.toString()), padding: pw.EdgeInsets.all(6)),
                pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${product.revenue.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Top Products by Revenue',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Quantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
              ],
            ),
            ..._analyticsData!.topProductsByRevenue.map((product) => pw.TableRow(
              children: [
                pw.Padding(child: pw.Text(product.productName), padding: pw.EdgeInsets.all(6)),
                pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${product.revenue.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                pw.Padding(child: pw.Text(product.quantitySold.toString()), padding: pw.EdgeInsets.all(6)),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfDailyRevenue() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Daily Revenue Breakdown',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
                pw.Padding(child: pw.Text('Orders', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(8)),
              ],
            ),
            ..._analyticsData!.dailyRevenue.map((day) => pw.TableRow(
              children: [
                pw.Padding(child: pw.Text(DateFormat('MMM dd').format(day.date)), padding: pw.EdgeInsets.all(6)),
                pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${day.revenue.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                pw.Padding(child: pw.Text(day.orders.toString()), padding: pw.EdgeInsets.all(6)),
              ],
            )),
          ],
        ),
      ],
    );
  }


  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Data Selected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a time period to view analytics',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showTimePeriodSelector,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Select Time Period'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading analytics data...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700]),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const Spacer(),
              if (title.contains('Revenue'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Net',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green[700]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _buildMetricCard('Total Revenue', '${Constants.CURRENCY_NAME}${_analyticsData!.totalRevenue.toStringAsFixed(0)}', Icons.attach_money, Colors.blue),
        _buildMetricCard('Net Revenue', '${Constants.CURRENCY_NAME}${_analyticsData!.netRevenue.toStringAsFixed(0)}', Icons.trending_up, Colors.green),
        _buildMetricCard('Total Orders', _analyticsData!.totalOrders.toString(), Icons.receipt_long, Colors.orange),
        _buildMetricCard('Avg Order', '${Constants.CURRENCY_NAME}${_analyticsData!.averageOrderValue.toStringAsFixed(0)}', Icons.show_chart, Colors.purple),
        _buildMetricCard('Tax Collected', '${Constants.CURRENCY_NAME}${_analyticsData!.totalTax.toStringAsFixed(0)}', Icons.receipt, Colors.teal),
        _buildMetricCard('Discounts', '${Constants.CURRENCY_NAME}${_analyticsData!.totalDiscounts.toStringAsFixed(0)}', Icons.local_offer, Colors.red),
        _buildMetricCard('Refunds', '${Constants.CURRENCY_NAME}${_analyticsData!.totalRefunds.toStringAsFixed(0)}', Icons.assignment_return, Colors.deepOrange),
        _buildMetricCard('Items Sold', _analyticsData!.topProductsByQuantity.fold(0, (sum, p) => sum + p.quantitySold).toString(), Icons.shopping_cart, Colors.indigo),
      ],
    );
  }

  Widget _buildPaymentMethodBreakdown() {
    final total = _analyticsData!.totalRevenue;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Methods',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _analyticsData!.paymentMethodBreakdown.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0.0';
                return Container(
                  width: 110,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getPaymentMethodColor(entry.key).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getPaymentMethodColor(entry.key).withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(_getPaymentMethodIcon(entry.key), size: 24, color: _getPaymentMethodColor(entry.key)),
                      const SizedBox(height: 6),
                      Text(
                        _capitalize(entry.key),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${Constants.CURRENCY_NAME}${entry.value.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _getPaymentMethodColor(entry.key)),
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'easypaisa/bank transfer':
        return Icons.account_balance_wallet;
      case 'credit':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case 'cash':
        return Colors.green;
      case 'easypaisa/bank transfer':
        return Colors.blue;
      case 'credit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRevenueChart() {
    final List<ChartData> chartData = _analyticsData!.dailyRevenue
        .map((day) => ChartData(DateFormat('MMM dd').format(day.date), day.revenue))
        .toList();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Revenue Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: chartData.length > 7 ? 45 : 0,
                  labelStyle: const TextStyle(fontSize: 10),
                ),
                primaryYAxis: NumericAxis(
                  labelFormat: '${Constants.CURRENCY_NAME}{value}',
                  title: AxisTitle(text: 'Revenue'),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<ChartData, String>>[
                  LineSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    color: Colors.blue,
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'By Quantity'),
                      Tab(text: 'By Revenue'),
                    ],
                  ),
                  SizedBox(
                    height: 280,
                    child: TabBarView(
                      children: [
                        _buildProductList(_analyticsData!.topProductsByQuantity, isQuantity: true),
                        _buildProductList(_analyticsData!.topProductsByRevenue, isQuantity: false),
                      ],
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

  Widget _buildProductList(List<TopProduct> products, {required bool isQuantity}) {
    if (products.isEmpty) {
      return const Center(
        child: Text('No products sold in this period'),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'SKU: ${product.productSku}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isQuantity)
                    Text(
                      '${product.quantitySold} sold',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    )
                  else
                    Text(
                      '${Constants.CURRENCY_NAME}${product.revenue.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  if (!isQuantity)
                    Text(
                      '${product.quantitySold} units',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showTimePeriodSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ThemeUtils.primary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThemeUtils.primary(context).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: ThemeUtils.primary(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedPeriod == TimePeriod.custom
                            ? '${DateFormat('MMM dd').format(_customStartDate)} - ${DateFormat('MMM dd').format(_customEndDate)}'
                            : _selectedPeriod.displayName,
                        style: TextStyle(fontWeight: FontWeight.w500, color: ThemeUtils.primary(context)),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: ThemeUtils.primary(context)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
            ),
          ),
          IconButton(
            onPressed: _exportToPDF,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'POS Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ThemeUtils.primary(context),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _analyticsData == null
                ? _buildEmptyState()
                : !_analyticsData!.hasData
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No data for selected period',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try selecting a different time range',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildKeyMetricsGrid(),
                  const SizedBox(height: 16),
                  _buildPaymentMethodBreakdown(),
                  _buildRevenueChart(),
                  _buildTopProductsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}