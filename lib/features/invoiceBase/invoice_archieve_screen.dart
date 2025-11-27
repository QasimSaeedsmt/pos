import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../cartBase/cart_base.dart';
import '../customerBase/customer_base.dart';
import '../main_navigation/main_navigation_base.dart';
import '../orderBase/order_base.dart';

class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  _OrdersManagementScreenState createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EnhancedPOSService _posService = EnhancedPOSService();
  String? _currentTenantId;

  List<AppOrder> _orders = [];
  List<AppOrder> _filteredOrders = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Filter and search variables
  String _searchQuery = '';
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // Sorting
  String _sortBy = 'date';
  bool _sortDescending = true;

  // Customer cache for enhanced display
  final Map<String, Customer> _customerCache = {};

  @override
  void initState() {
    super.initState();
    _setTenantContext();
    _loadOrders();
  }

  void _setTenantContext() {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final tenantId = authProvider.currentUser?.tenantId;

    if (tenantId != null && tenantId != 'super_admin') {
      _currentTenantId = tenantId;
      _posService.setTenantContext(tenantId);
    }
  }

  CollectionReference get ordersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('orders');

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final snapshot = await ordersRef
          .orderBy('dateCreated', descending: true)
          .get();

      final orders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppOrder.fromFirestore(data, doc.id);
      }).toList();

      // Pre-load customer data for orders that have customer IDs
      await _preloadCustomerData(orders);

      setState(() {
        _orders = orders;
        _filteredOrders = orders;
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

  // Pre-load customer data for better performance and display
  Future<void> _preloadCustomerData(List<AppOrder> orders) async {
    final customerIds = orders
        .where((order) => order.hasCustomerId)
        .map((order) => order.customerId!)
        .toSet()
        .toList();

    print('🔄 Pre-loading customer data for ${customerIds.length} customers');

    for (final customerId in customerIds) {
      if (!_customerCache.containsKey(customerId)) {
        try {
          final customer = await _posService.getCustomerById(customerId);
          if (customer != null) {
            _customerCache[customerId] = customer;
            print('✅ Loaded customer: ${customer.fullName} ($customerId)');
          }
        } catch (e) {
          print('❌ Failed to load customer $customerId: $e');
        }
      }
    }
  }

  void _applyFilters() {
    List<AppOrder> filtered = _orders;

    // Apply date filter
    if (_selectedStartDate != null) {
      filtered = filtered.where((order) =>
          order.dateCreated.isAfter(_selectedStartDate!)).toList();
    }
    if (_selectedEndDate != null) {
      filtered = filtered.where((order) =>
          order.dateCreated.isBefore(_selectedEndDate!.add(Duration(days: 1)))).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        final query = _searchQuery.toLowerCase();
        return order.number.toLowerCase().contains(query) ||
            order.customerDisplayName.toLowerCase().contains(query) ||
            order.customerContactInfo.toLowerCase().contains(query) ||
            order.id.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'date':
          comparison = a.dateCreated.compareTo(b.dateCreated);
          break;
        case 'total':
          comparison = a.total.compareTo(b.total);
          break;
        case 'number':
          comparison = a.number.compareTo(b.number);
          break;
        case 'customer':
          comparison = a.customerDisplayName.compareTo(b.customerDisplayName);
          break;
        default:
          comparison = 0;
      }
      return _sortDescending ? -comparison : comparison;
    });

    setState(() {
      _filteredOrders = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStartDate = null;
      _selectedEndDate = null;
      _sortBy = 'date';
      _sortDescending = true;
    });
    _applyFilters();
  }

  Future<void> _generateAndShareInvoice(AppOrder order) async {
    try {
      final pdf = await _generateInvoicePDF(order);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${order.number}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice for Order ${order.number}',
      );
    } catch (e) {
      _showErrorSnackbar('Failed to generate invoice: $e');
    }
  }

  Future<void> _printInvoice(AppOrder order) async {
    try {
      final pdf = await _generateInvoicePDF(order);
      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to print invoice: $e');
    }
  }

  Future<pw.Document> _generateInvoicePDF(AppOrder order) async {
    final pdf = pw.Document();
    final enhancedData = order.extractEnhancedData();
    final cartData = enhancedData['cartData'] as Map<String, dynamic>?;
    final pricingBreakdown = cartData?['pricing_breakdown'] as Map<String, dynamic>?;

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          _buildInvoiceHeader(order),
          pw.SizedBox(height: 20),
          _buildOrderDetails(order),
          pw.SizedBox(height: 20),
          _buildLineItemsTable(order),
          pw.SizedBox(height: 20),
          _buildInvoiceSummary(order, pricingBreakdown),
          pw.SizedBox(height: 30),
          _buildThankYouMessage(),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildInvoiceHeader(AppOrder order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text('Order #${order.number}'),
            pw.Text('Date: ${DateFormat('MMM dd, yyyy').format(order.dateCreated)}'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Your Business Name',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text('Business Address'),
            pw.Text('City, State ZIP'),
            pw.Text('Phone: (123) 456-7890'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildOrderDetails(AppOrder order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Bill To:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(order.customerDisplayName),
            if (order.customerContactInfo != 'No contact information')
              pw.Text(order.customerContactInfo),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Order Status:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(order.statusDisplay),
            pw.SizedBox(height: 10),
            pw.Text(
              'Payment Method:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(order.getPaymentMethod().toUpperCase()),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildLineItemsTable(AppOrder order) {
    final headers = ['Item', 'Qty', 'Price', 'Discount', 'Total'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: _extractLineItemsData(order),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

// Add this method to extract line items data properly
  List<List<String>> _extractLineItemsData(AppOrder order) {
    final data = <List<String>>[];

    for (var item in order.lineItems) {
      try {
        final itemData = _extractItemData(item);
        data.add([
          itemData['name'] ?? 'Unknown Item',
          itemData['quantity'].toString(),
          itemData['price'].toStringAsFixed(2),
          itemData['discount'].toStringAsFixed(2),
          itemData['total'].toStringAsFixed(2),
        ]);
      } catch (e) {
        print('Error processing line item: $e');
        // Safe fallback
        data.add(['Unknown Item', '1', '0.00', '0.00', '0.00']);
      }
    }

    return data;
  }

// Add this method to extract item data from different possible structures
  Map<String, dynamic> _extractItemData(dynamic item) {
    // If it's already a CartItem object
    if (item is CartItem) {
      return {
        'name': item.product.name,
        'quantity': item.quantity,
        'price': item.product.price,
        'discount': item.discountAmount,
        'total': item.subtotal,
      };
    }

    // If it's a Firestore map (from order storage)
    if (item is Map<String, dynamic>) {
      return _extractFromFirestoreMap(item);
    }

    // Try to convert to map as last resort
    try {
      final itemMap = Map<String, dynamic>.from(item as Map);
      return _extractFromFirestoreMap(itemMap);
    } catch (e) {
      print('Failed to extract item data: $e');
      return {'name': 'Unknown Item', 'quantity': 1, 'price': 0.0, 'discount': 0.0, 'total': 0.0};
    }
  }

// Add this method to extract from Firestore-stored order items
  Map<String, dynamic> _extractFromFirestoreMap(Map<String, dynamic> itemMap) {
    // Try multiple possible field names for each property
    final name = itemMap['productName']?.toString() ??
        itemMap['name']?.toString() ??
        'Unknown Item';

    final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 1;

    final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

    // Calculate discount from various possible fields
    double discount = 0.0;
    if (itemMap['discountAmount'] != null) {
      discount = (itemMap['discountAmount'] as num).toDouble();
    } else if (itemMap['manualDiscount'] != null) {
      discount = (itemMap['manualDiscount'] as num).toDouble() * quantity;
    }

    // Calculate total - try direct field first, then calculate
    double total = (itemMap['subtotal'] as num?)?.toDouble() ??
        (price * quantity) - discount;

    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'total': total,
    };
  }
  pw.Widget _buildInvoiceSummary(AppOrder order, Map<String, dynamic>? pricingBreakdown) {
    final subtotal = pricingBreakdown?['subtotal'] as double? ?? order.calculateSubtotal();
    final totalDiscount = pricingBreakdown?['total_discount'] as double? ?? order.calculateTotalDiscount();
    final taxAmount = pricingBreakdown?['tax_amount'] as double? ?? order.calculateTaxAmount();
    final shippingAmount = pricingBreakdown?['shipping_amount'] as double? ?? order.calculateShippingAmount();
    final tipAmount = pricingBreakdown?['tip_amount'] as double? ?? order.calculateTipAmount();

    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildSummaryRow('Subtotal', subtotal),
          if (totalDiscount > 0) _buildSummaryRow('Discounts', -totalDiscount),
          if (taxAmount > 0) _buildSummaryRow('Tax', taxAmount),
          if (shippingAmount > 0) _buildSummaryRow('Shipping', shippingAmount),
          if (tipAmount > 0) _buildSummaryRow('Tip', tipAmount),
          pw.Divider(),
          _buildSummaryRow('TOTAL', order.total, isTotal: true),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: isTotal
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)
                : null,
          ),
          pw.Text(
            '${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: isTotal
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)
                : null,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildThankYouMessage() {
    return pw.Center(
      child: pw.Text(
        'Thank you for your business!',
        style: pw.TextStyle(
          fontSize: 12,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey600,
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Enhanced order details with real customer data
  void _showOrderDetails(AppOrder order, Customer? customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOrderDetailsSheet(order, customer),
    );
  }

  Widget _buildOrderDetailsSheet(AppOrder order, Customer? customer) {
    final enhancedData = order.extractEnhancedData();
    final cartData = enhancedData['cartData'] as Map<String, dynamic>?;
    final pricingBreakdown = cartData?['pricing_breakdown'] as Map<String, dynamic>?;

    // Use real customer data if available, otherwise fallback to order data
    final String displayName = customer?.displayName ?? order.customerDisplayName;
    final String contactInfo = customer != null
        ? (customer.phone.isNotEmpty ? customer.phone : customer.email)
        : order.customerContactInfo;
    final String detailedInfo = customer != null
        ? _formatCustomerDetailedInfo(customer)
        : order.customerDetailedInfo;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: order.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: order.statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(order.statusIcon, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.number}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          order.statusDisplay,
                          style: TextStyle(
                            color: order.statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
        
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information
                    _buildDetailSection(
                      icon: Icons.person,
                      title: 'Customer Information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (customer != null) ...[
                            // Real customer data
                            Text(
                              customer.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (customer.company?.isNotEmpty == true)
                              Text(
                                customer.company!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            SizedBox(height: 8),
                            if (customer.email.isNotEmpty)
                              Text(
                                customer.email,
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            if (customer.phone.isNotEmpty)
                              Text(
                                customer.phone,
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            if (customer.address1?.isNotEmpty == true)
                              Text(
                                _formatCustomerAddress(customer),
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            if (customer.orderCount > 0)
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${customer.orderCount} previous orders • ${Constants.CURRENCY_NAME}${customer.totalSpent.toStringAsFixed(2)} spent',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ] else ...[
                            // Fallback to order customer data
                            Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: displayName == 'Walk-in Customer'
                                    ? Colors.grey[600]
                                    : Colors.grey[800],
                              ),
                            ),
                            if (contactInfo != 'No contact information')
                              Text(
                                contactInfo,
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            if (detailedInfo != 'Walk-in Customer' && detailedInfo.contains('\n'))
                              ...detailedInfo.split('\n').map((line) =>
                                  Text(line, style: TextStyle(fontSize: 14, color: Colors.grey[600]))
                              ).toList(),
                          ],
                        ],
                      ),
                    ),
        
                    SizedBox(height: 16),
        
                    // Order Information
                    _buildDetailSection(
                      icon: Icons.receipt,
                      title: 'Order Information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(order.dateCreated)}',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Payment Method: ${order.getPaymentMethod().toUpperCase()}',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Total Items: ${order.totalItems}',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
        
                    SizedBox(height: 16),
        
                    // Order Items
                    _buildDetailSection(
                      icon: Icons.shopping_cart,
                      title: 'Order Items (${order.lineItems.length})',
                      child: Column(
                        children: order.lineItems.map((item) {
                          final itemData = _extractItemData(item);
                          final name = itemData['name']!;
                          final quantity = itemData['quantity'] as int;
                          final price = itemData['price'] as double;
                          final discount = itemData['discount'] as double;
                          final total = itemData['total'] as double;

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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.shopping_bag, color: Colors.blue),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: 4),
                                      Text('Qty: $quantity • ${Constants.CURRENCY_NAME}$price each'),
                                      if (discount > 0)
                                        Text(
                                          'Discount: -${Constants.CURRENCY_NAME}$discount',
                                          style: TextStyle(color: Colors.red, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${Constants.CURRENCY_NAME}${total.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
        
                    SizedBox(height: 16),
        
                    // Order Summary
                    _buildDetailSection(
                      icon: Icons.calculate,
                      title: 'Order Summary',
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryItem('Subtotal', pricingBreakdown?['subtotal'] ?? order.calculateSubtotal()),
                            if ((pricingBreakdown?['total_discount'] ?? 0.0) > 0)
                              _buildSummaryItem('Discounts', -(pricingBreakdown?['total_discount'] ?? 0.0), isNegative: true),
                            if ((pricingBreakdown?['tax_amount'] ?? 0.0) > 0)
                              _buildSummaryItem('Tax', pricingBreakdown?['tax_amount'] ?? 0.0),
                            if ((pricingBreakdown?['shipping_amount'] ?? 0.0) > 0)
                              _buildSummaryItem('Shipping', pricingBreakdown?['shipping_amount'] ?? 0.0),
                            if ((pricingBreakdown?['tip_amount'] ?? 0.0) > 0)
                              _buildSummaryItem('Tip', pricingBreakdown?['tip_amount'] ?? 0.0),
                            Divider(),
                            _buildSummaryItem('TOTAL', order.total, isTotal: true),
                          ],
                        ),
                      ),
                    ),
        
                    SizedBox(height: 30),
        
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.print),
                            label: Text('Print Invoice'),
                            onPressed: () {
                              Navigator.pop(context);
                              _printInvoice(order);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Theme.of(context).primaryColor),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.share),
                            label: Text('Share Invoice'),
                            onPressed: () {
                              Navigator.pop(context);
                              _generateAndShareInvoice(order);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, {bool isNegative = false, bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}${Constants.CURRENCY_NAME}${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Theme.of(context).primaryColor : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced order item display with real customer data
  Widget _buildOrderItem(AppOrder order) {
    // Get customer from cache if available
    final Customer? customer = order.hasCustomerId
        ? _customerCache[order.customerId!]
        : null;

    final String displayName;
    final String contactInfo;
    final bool isRealCustomer;

    if (customer != null) {
      // Use real customer data from cache
      displayName = customer.displayName;
      contactInfo = customer.phone.isNotEmpty
          ? customer.phone
          : (customer.email.isNotEmpty ? customer.email : 'No contact information');
      isRealCustomer = true;
    } else {
      // Fallback to order's stored customer data
      displayName = order.customerDisplayName;
      contactInfo = order.customerContactInfo;
      isRealCustomer = order.hasRealCustomerData;
    }

    // Calculate time difference for "X time ago" display
    final timeAgo = _getTimeAgo(order.dateCreated);

    // Determine status badge color and icon
    final statusStyle = _getStatusStyle(order.statusDisplay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth > 600;
        final bool isMediumScreen = constraints.maxWidth > 400;

        return Container(
          margin: EdgeInsets.symmetric(
            vertical: 6,
            horizontal: isLargeScreen ? 20 : 12,
          ),
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showOrderDetails(order, customer),
              splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
              highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
              child: Container(
                padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: isLargeScreen ? _buildLargeLayout(
                  context, order, customer, displayName, contactInfo,
                  isRealCustomer, timeAgo, statusStyle,
                ) : _buildSmallLayout(
                  context, order, customer, displayName, contactInfo,
                  isRealCustomer, timeAgo, statusStyle, isMediumScreen,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
// Large screen layout (tablet/desktop)
  Widget _buildLargeLayout(
      BuildContext context,
      AppOrder order,
      Customer? customer,
      String displayName,
      String contactInfo,
      bool isRealCustomer,
      String timeAgo,
      _StatusStyle statusStyle,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Indicator
        Container(
          width: 4,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusStyle.color,
                statusStyle.color.withOpacity(0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 16),

        // Customer Avatar & Main Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Avatar
                  _buildCustomerAvatar(context, customer, isRealCustomer),
                  SizedBox(width: 12),

                  // Order Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Number & Status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Order #${order.number}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            _buildStatusBadge(context, statusStyle, order.statusDisplay),
                          ],
                        ),
                        SizedBox(height: 6),

                        // Customer Name
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isRealCustomer
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),

                        // Contact Info & Company
                        if (contactInfo != 'No contact information')
                          Text(
                            contactInfo,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                        if (customer != null && customer.company?.isNotEmpty == true)
                          Text(
                            customer.company!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Order Details Row
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    // Date & Time
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.access_time,
                        value: timeAgo,
                        subtitle: DateFormat('MMM dd, yyyy').format(order.dateCreated),
                      ),
                    ),
                    SizedBox(width: 16),

                    // Items Count
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.shopping_bag,
                        value: '${order.totalItems}',
                        subtitle: 'items',
                      ),
                    ),
                    SizedBox(width: 16),

                    // Payment Method
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.payment,
                        value: order.getPaymentMethod(),
                        subtitle: 'Payment',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 16),

        // Total Amount & Quick Actions
        Container(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Total Amount
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).primaryColor,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),

              // Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Print Button
                  _buildActionButton(
                    icon: Icons.print_outlined,
                    onTap: () => _printInvoice(order),
                    tooltip: 'Print Invoice',
                  ),
                  SizedBox(width: 8),

                  // Share Button
                  _buildActionButton(
                    icon: Icons.share_outlined,
                    onTap: () => _generateAndShareInvoice(order),
                    tooltip: 'Share Invoice',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  // Updated action button with size parameter
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    double size = 36,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[200]!,
              ),
            ),
            child: Icon(
              icon,
              size: size * 0.45,
              color: Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

// Helper method for payment method abbreviation
  String _abbreviatePaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'easypaisa/bank transfer':
        return 'Bank';
      case 'credit':
        return 'Credit';
      case 'card':
        return 'Card';
      default:
        return method.length > 6 ? '${method.substring(0, 6)}...' : method;
    }
  }
// Reusable status badge widget
  Widget _buildStatusBadge(BuildContext context, _StatusStyle statusStyle, String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusStyle.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusStyle.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusStyle.icon,
            size: 10,
            color: statusStyle.color,
          ),
          SizedBox(width: 4),
          Text(
            status.length > 8 ? '${status.substring(0, 8)}...' : status,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: statusStyle.color,
            ),
          ),
        ],
      ),
    );
  }
  // Reusable customer avatar widget
  Widget _buildCustomerAvatar(BuildContext context, Customer? customer, bool isRealCustomer) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isRealCustomer
              ? [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColorDark,
          ]
              : [
            Colors.grey[400]!,
            Colors.grey[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              isRealCustomer ? Icons.person : Icons.person_outline,
              color: Colors.white,
              size: 18,
            ),
          ),
          if (isRealCustomer && customer != null && customer.orderCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    customer.orderCount > 9 ? '9+' : '${customer.orderCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  // Small screen layout (mobile)
  Widget _buildSmallLayout(
      BuildContext context,
      AppOrder order,
      Customer? customer,
      String displayName,
      String contactInfo,
      bool isRealCustomer,
      String timeAgo,
      _StatusStyle statusStyle,
      bool isMediumScreen,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Avatar
            _buildCustomerAvatar(context, customer, isRealCustomer),
            SizedBox(width: 12),

            // Order Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Number & Status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${order.number}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      _buildStatusBadge(context, statusStyle, order.statusDisplay),
                    ],
                  ),
                  SizedBox(height: 4),

                  // Customer Name
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isRealCustomer
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Contact Info
                  if (contactInfo != 'No contact information')
                    Text(
                      contactInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        // Order Details - Horizontal Scroll for small screens
        Container(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: _buildDetailItem(
                  icon: Icons.access_time,
                  value: timeAgo,
                  subtitle: DateFormat('MM/dd/yy').format(order.dateCreated),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: _buildDetailItem(
                  icon: Icons.shopping_bag,
                  value: '${order.totalItems}',
                  subtitle: 'items',
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: _buildDetailItem(
                  icon: Icons.payment,
                  value: _abbreviatePaymentMethod(order.getPaymentMethod()),
                  subtitle: 'Payment',
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Bottom Row - Total and Actions
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Total Amount
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.1),
                        Theme.of(context).primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Quick Actions
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.print_outlined,
                    onTap: () => _printInvoice(order),
                    tooltip: 'Print Invoice',
                    size: 32,
                  ),
                  SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.share_outlined,
                    onTap: () => _generateAndShareInvoice(order),
                    tooltip: 'Share Invoice',
                    size: 32,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Company name on new line for small screens
        if (customer != null && customer.company?.isNotEmpty == true)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              customer.company!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  // Helper widget for detail items
  Widget _buildDetailItem({
    required IconData icon,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.grey[600],
              ),
              SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  }
  String _formatCustomerDetailedInfo(Customer customer) {
    final details = <String>[];
    details.add(customer.displayName);

    if (customer.email.isNotEmpty) details.add(customer.email);
    if (customer.phone.isNotEmpty) details.add(customer.phone);

    final address = _formatCustomerAddress(customer);
    if (address.isNotEmpty) details.add(address);

    return details.join('\n');
  }

  String _formatCustomerAddress(Customer customer) {
    final addressParts = [
      customer.address1,
      customer.city,
      customer.state,
      customer.postcode,
      customer.country,
    ].where((part) => part != null && part.isNotEmpty).toList();

    return addressParts.join(', ');
  }

  Widget _buildFiltersPanel() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Filters & Sorting',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                TextButton.icon(
                  icon: Icon(Icons.clear, size: 16),
                  label: Text('Clear'),
                  onPressed: _clearFilters,
                ),
              ],
            ),
            SizedBox(height: 16),

            // Search
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by order number, customer...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            ),

            SizedBox(height: 16),

            // Date Filter
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.calendar_today, size: 16),
                    label: Text(_selectedStartDate != null
                        ? DateFormat('MMM dd, yyyy').format(_selectedStartDate!)
                        : 'Start Date'
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedStartDate = date;
                        });
                        _applyFilters();
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(Icons.calendar_today, size: 16),
                    label: Text(_selectedEndDate != null
                        ? DateFormat('MMM dd, yyyy').format(_selectedEndDate!)
                        : 'End Date'
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedEndDate = date;
                        });
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Sorting
            Row(
              children: [
                Text('Sort by:', style: TextStyle(fontWeight: FontWeight.w500)),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  items: [
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                    DropdownMenuItem(value: 'total', child: Text('Total')),
                    DropdownMenuItem(value: 'number', child: Text('Order #')),
                    DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    _applyFilters();
                  },
                ),
                SizedBox(width: 16),
                IconButton(
                  icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
                  onPressed: () {
                    setState(() {
                      _sortDescending = !_sortDescending;
                    });
                    _applyFilters();
                  },
                ),
              ],
            ),
          ],
        ),
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
          Text(
            'Loading Orders...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
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
          Text(
            'Failed to load orders',
            style: TextStyle(fontSize: 18, color: Colors.grey[800]),
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Orders Found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Orders will appear here once they are created',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _clearFilters,
            icon: Icon(Icons.clear_all),
            label: Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Orders Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh Orders',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Panel
          _buildFiltersPanel(),

          // Results Count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filteredOrders.length} orders found',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Spacer(),
                if (_filteredOrders.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.print, size: 20),
                    onPressed: () {
                      _showErrorSnackbar('Bulk printing feature coming soon!');
                    },
                    tooltip: 'Print All',
                  ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                ? _buildErrorState()
                : _filteredOrders.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView.builder(
                itemCount: _filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = _filteredOrders[index];
                  return _buildOrderItem(order);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _StatusStyle {
  final Color color;
  final IconData icon;

  _StatusStyle(this.color, this.icon);
}

_StatusStyle _getStatusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return _StatusStyle(Colors.green, Icons.check_circle);
    case 'pending':
      return _StatusStyle(Colors.orange, Icons.pending);
    case 'processing':
      return _StatusStyle(Colors.blue, Icons.autorenew);
    case 'cancelled':
      return _StatusStyle(Colors.red, Icons.cancel);
    case 'refunded':
      return _StatusStyle(Colors.purple, Icons.money_off);
    default:
      return _StatusStyle(Colors.grey, Icons.info);
  }
}
