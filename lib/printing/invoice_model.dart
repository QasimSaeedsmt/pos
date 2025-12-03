import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../core/models/app_order_model.dart';
import '../core/models/customer_model.dart';
import '../features/credit/credit_sale_model.dart';
import '../features/users/users_base.dart';
import 'invoice_service.dart';

class InvoiceOptionsBottomSheetWithNoOptions extends StatelessWidget {
  final AppOrder order;
  final Customer? customer;
  final Map<String, dynamic> businessInfo;
  final Map<String, dynamic> invoiceSettings;
  final AppUser? currentUser;

  const InvoiceOptionsBottomSheetWithNoOptions({
    super.key,
    required this.order,
    this.customer,
    required this.businessInfo,
    required this.invoiceSettings,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
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
      ),
    );
  }

  void _printInvoice(BuildContext context) {
    final invoice = Invoice.fromOrder(
      order,
      customer,
      businessInfo,
      invoiceSettings,
      templateType: invoiceSettings['defaultTemplate'] ?? 'traditional',
      printedBy: currentUser?.formattedName,
    );

    InvoiceService().printInvoice(invoice, currentUser: currentUser);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice sent to printer'))
    );

    Navigator.pop(context);
  }
}

class InvoiceOptionsBottomSheetWithOptions extends StatefulWidget {
  final AppOrder order;
  final Customer? customer;
  final Map<String, dynamic>? enhancedData;
  final AppUser? currentUser;

  const InvoiceOptionsBottomSheetWithOptions({
    super.key,
    required this.order,
    this.customer,
    this.enhancedData,
    this.currentUser,
  });

  @override
  _InvoiceOptionsBottomSheetWithOptionsState createState() => _InvoiceOptionsBottomSheetWithOptionsState();
}

class _InvoiceOptionsBottomSheetWithOptionsState extends State<InvoiceOptionsBottomSheetWithOptions> {
  String _selectedTemplate = 'traditional';
  bool _autoPrint = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTemplate = prefs.getString('default_invoice_template') ?? 'traditional';
      _autoPrint = prefs.getBool('auto_print') ?? false;
    });
  }

  Future<Map<String, dynamic>> _getBusinessInfo() async {
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

  Future<Map<String, dynamic>> _getInvoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'defaultTemplate': prefs.getString('default_invoice_template') ?? 'traditional',
      'taxRate': prefs.getDouble('tax_rate') ?? 0.0,
      'discountRate': prefs.getDouble('discount_rate') ?? 0.0,
      'autoPrint': prefs.getBool('auto_print') ?? false,
      'includeCustomerDetails': prefs.getBool('include_customer_details') ?? true,
      'defaultNotes': prefs.getString('default_notes') ?? 'Thank you for your business!',
    };
  }

  void _generateInvoice() async {
    final businessInfo = await _getBusinessInfo();
    final invoiceSettings = await _getInvoiceSettings();

    final invoice = widget.enhancedData != null
        ? Invoice.fromEnhancedOrder(
      widget.order,
      widget.customer,
      businessInfo,
      invoiceSettings,
      templateType: _selectedTemplate,
      enhancedData: widget.enhancedData,
      printedBy: widget.currentUser?.formattedName,
    )
        : Invoice.fromOrder(
      widget.order,
      widget.customer,
      businessInfo,
      invoiceSettings,
      templateType: _selectedTemplate,
      printedBy: widget.currentUser?.formattedName,
    );
    final pdfFile = await InvoiceService().generatePdfInvoice(
        invoice,
        currentUser: widget.currentUser
    );

    if (_autoPrint) {
      await InvoiceService().printInvoice(invoice, currentUser: widget.currentUser);
    }

    _showSuccessDialog(invoice, pdfFile);
  }

  void _showSuccessDialog(Invoice invoice, File pdfFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice Generated'),
        content: Text('Invoice ${invoice.invoiceNumber} has been generated successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              InvoiceService().printInvoice(invoice, currentUser: widget.currentUser);
            },
            child: Text('Print'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              InvoiceService().shareInvoice(invoice);
            },
            child: Text('Share/Export'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Generate Invoice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            if (widget.enhancedData != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.discount, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enhanced pricing data available',
                          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // User attribution info
            if (widget.currentUser != null)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Processed by: ${widget.currentUser!.formattedName}',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.currentUser!.role != UserRole.cashier)
                              Text(
                                _getUserRoleDisplay(widget.currentUser!.role),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice Template', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildTemplateOption('Traditional A4', 'traditional', Icons.description),
                        _buildTemplateOption('Thermal Receipt', 'thermal', Icons.receipt),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(child: Text('Auto Print After Generation')),
                    Switch(
                      value: _autoPrint,
                      onChanged: (value) => setState(() => _autoPrint = value),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Skip'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateInvoice,
                    icon: Icon(Icons.receipt_long),
                    label: Text('Generate Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateOption(String label, String value, IconData icon) {
    final isSelected = _selectedTemplate == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedTemplate = value),
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[800] : Colors.grey[800],
      ),
    );
  }

  String _getUserRoleDisplay(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.clientAdmin:
        return 'Administrator';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.salesInventoryManager:
        return 'Sales Manager';
      default:
        return 'Staff';
    }
  }
}

class Invoice {
  final String id;
  final String orderId;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime? dueDate;
  final Customer? customer;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final String notes;
  final Map<String, dynamic> businessInfo;
  final Map<String, dynamic> invoiceSettings;
  final String templateType;
  final Map<String, dynamic>? enhancedData;
  final bool hasEnhancedPricing;

  // Credit-specific properties
  final bool isCreditSale;
  final double? creditAmount;
  final double? paidAmount;
  final DateTime? creditDueDate;
  final String? creditTerms;
  final double? previousBalance;
  final double? newBalance;
  final CreditSaleData? creditSaleData;

  // User attribution properties
  final String? printedBy;
  final DateTime? printedAt;

  // Getters
  String? get logoPath => businessInfo['logoPath'] as String?;
  bool get includeLogo => invoiceSettings['includeLogo'] as bool? ?? true;
  bool get showCustomerDetails => customer != null && (invoiceSettings['includeCustomerDetails'] ?? true);
  bool get showItemDiscounts => hasEnhancedPricing && items.any((item) => item.hasManualDiscount);
  bool get showCartDiscount => hasEnhancedPricing && cartDiscountAmount > 0;
  bool get showAdditionalDiscount => hasEnhancedPricing && additionalDiscountAmount > 0;
  bool get showShipping => hasEnhancedPricing && shippingAmount > 0;
  bool get showTip => hasEnhancedPricing && tipAmount > 0;
  bool get showTax => taxAmount > 0;

  // Credit-related getters
  bool get showCreditDetails => isCreditSale && creditAmount != null;
  bool get hasPartialPayment => isCreditSale && (paidAmount ?? 0) > 0;
  bool get isOverdueCredit => creditDueDate != null && creditDueDate!.isBefore(DateTime.now());
  int get daysOverdue => creditDueDate != null && isOverdueCredit
      ? DateTime.now().difference(creditDueDate!).inDays
      : 0;

  // User attribution getters
  bool get showPrintedBy => printedBy != null && printedBy!.isNotEmpty;

  double get totalItemDiscounts {
    if (hasEnhancedPricing) {
      return items.fold(0.0, (sum, item) => sum + (item.discountAmount ?? 0.0));
    }
    return discountAmount;
  }

  double get cartDiscountAmount {
    if (hasEnhancedPricing) {
      final cartData = enhancedData?['cartData'] as Map<String, dynamic>?;
      if (cartData != null) {
        final cartDiscount = (cartData['cartDiscount'] as num?)?.toDouble() ?? 0.0;
        final cartDiscountPercent = (cartData['cartDiscountPercent'] as num?)?.toDouble() ?? 0.0;
        final cartSubtotal = (cartData['subtotal'] as num?)?.toDouble() ?? subtotal;
        return cartDiscount + (cartSubtotal * cartDiscountPercent / 100);
      }
    }
    return 0.0;
  }

  double get additionalDiscountAmount => hasEnhancedPricing
      ? (enhancedData?['additionalDiscount'] as num? ?? 0.0).toDouble()
      : 0.0;

  double get totalSavings => totalItemDiscounts + cartDiscountAmount + additionalDiscountAmount;

  double get netAmount => subtotal - totalSavings;

  double get shippingAmount => hasEnhancedPricing
      ? (enhancedData?['shippingAmount'] as num? ?? 0.0).toDouble()
      : 0.0;

  double get tipAmount => hasEnhancedPricing
      ? (enhancedData?['tipAmount'] as num? ?? 0.0).toDouble()
      : 0.0;

  Map<String, double> get allDiscounts {
    final discounts = <String, double>{};

    if (hasEnhancedPricing) {
      discounts['item_discounts'] = totalItemDiscounts;
      discounts['cart_discount'] = cartDiscountAmount;
      discounts['additional_discount'] = additionalDiscountAmount;

      final settingsDiscountRate = (invoiceSettings['discountRate'] as num?)?.toDouble() ?? 0.0;
      final settingsDiscount = subtotal * settingsDiscountRate / 100;
      if (settingsDiscount > 0) {
        discounts['settings_discount'] = settingsDiscount;
      }
    } else {
      discounts['legacy_discount'] = discountAmount;
    }

    return discounts;
  }

  Map<String, dynamic>? get pricingBreakdown => hasEnhancedPricing
      ? enhancedData?['cartData']?['pricing_breakdown'] as Map<String, dynamic>?
      : null;

  Invoice({
    required this.id,
    required this.orderId,
    required this.invoiceNumber,
    required this.issueDate,
    this.dueDate,
    this.customer,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    required this.notes,
    required this.businessInfo,
    required this.invoiceSettings,
    required this.templateType,
    this.enhancedData,
    this.hasEnhancedPricing = false,
    this.isCreditSale = false,
    this.creditAmount,
    this.paidAmount,
    this.creditDueDate,
    this.creditTerms,
    this.previousBalance,
    this.newBalance,
    this.creditSaleData,
    this.printedBy,
    this.printedAt,
  });

  factory Invoice.fromEnhancedOrder(
      AppOrder order,
      Customer? customer,
      Map<String, dynamic> businessInfo,
      Map<String, dynamic> invoiceSettings, {
        String templateType = 'traditional',
        Map<String, dynamic>? enhancedData,
        CreditSaleData? creditSaleData,
        String? printedBy,
      }) {
    final enhancedItems = _createEnhancedItems(order.lineItems, enhancedData ?? {});

    final cartData = enhancedData?['cartData'] as Map<String, dynamic>?;
    final discountBreakdown = enhancedData?['discountBreakdown'] as Map<String, dynamic>?;

    final subtotal = (cartData?['subtotal'] as num?)?.toDouble() ?? 0.0;
    final totalDiscount = (discountBreakdown?['total_savings'] as num?)?.toDouble() ?? 0.0;

    final netAmount = subtotal - totalDiscount;

    final shippingAmount = (enhancedData?['shippingAmount'] as num?)?.toDouble() ?? 0.0;
    final tipAmount = (enhancedData?['tipAmount'] as num?)?.toDouble() ?? 0.0;

    final taxRate = (invoiceSettings['taxRate'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (discountBreakdown?['tax_amount'] as num?)?.toDouble() ??
        (netAmount * taxRate / 100);

    final totalAmount = netAmount + taxAmount + shippingAmount + tipAmount;

    final isCreditSale = creditSaleData?.isCreditSale ?? enhancedData?['isCreditSale'] ?? false;
    final creditAmount = creditSaleData?.creditAmount ?? (enhancedData?['creditAmount'] as num?)?.toDouble();
    final paidAmount = creditSaleData?.paidAmount ?? (enhancedData?['paidAmount'] as num?)?.toDouble();
    final creditDueDate = creditSaleData?.dueDate;
    final previousBalance = creditSaleData?.previousBalance;
    final newBalance = creditSaleData?.newBalance;

    return Invoice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: order.id,
      invoiceNumber: 'INV-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${order.number}',
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(Duration(days: 30)),
      customer: customer,
      items: enhancedItems,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: totalDiscount,
      totalAmount: totalAmount,
      paymentMethod: enhancedData?['paymentMethod']?.toString() ?? 'cash',
      status: 'paid',
      notes: invoiceSettings['defaultNotes']?.toString() ?? 'Thank you for your business!',
      businessInfo: businessInfo,
      invoiceSettings: invoiceSettings,
      templateType: templateType,
      enhancedData: enhancedData,
      hasEnhancedPricing: true,
      isCreditSale: isCreditSale,
      creditAmount: creditAmount,
      paidAmount: paidAmount,
      creditDueDate: creditDueDate,
      previousBalance: previousBalance,
      newBalance: newBalance,
      creditSaleData: creditSaleData,
      printedBy: printedBy,
      printedAt: DateTime.now(),
    );
  }

  static List<InvoiceItem> _createEnhancedItems(List<dynamic> lineItems, Map<String, dynamic> enhancedData) {
    final cartData = enhancedData['cartData'] as Map<String, dynamic>?;
    final enhancedLineItems = cartData?['line_items'] as List<dynamic>? ?? cartData?['items'] as List<dynamic>?;

    return lineItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final enhancedItem = enhancedLineItems != null && enhancedLineItems.length > index
          ? enhancedLineItems[index]
          : null;

      return InvoiceItem(
        name: item['productName']?.toString() ?? 'Unknown Product',
        description: item['productSku']?.toString() ?? '',
        quantity: (item['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (item['price'] as num?)?.toDouble() ?? 0.0,
        total: (enhancedItem?['final_subtotal'] as num?)?.toDouble() ??
            (enhancedItem?['subtotal'] as num?)?.toDouble() ??
            ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1),
        basePrice: (enhancedItem?['base_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble(),
        manualDiscount: (enhancedItem?['manual_discount'] as num?)?.toDouble() ?? (enhancedItem?['manualDiscount'] as num?)?.toDouble(),
        manualDiscountPercent: (enhancedItem?['manual_discount_percent'] as num?)?.toDouble() ?? (enhancedItem?['manualDiscountPercent'] as num?)?.toDouble(),
        discountAmount: (enhancedItem?['discount_amount'] as num?)?.toDouble() ?? (enhancedItem?['discountAmount'] as num?)?.toDouble(),
        baseSubtotal: (enhancedItem?['base_subtotal'] as num?)?.toDouble() ?? (enhancedItem?['baseSubtotal'] as num?)?.toDouble(),
        hasManualDiscount: enhancedItem?['has_manual_discount'] ?? enhancedItem?['hasManualDiscount'] ?? false,
      );
    }).toList();
  }

  factory Invoice.fromOrder(
      AppOrder order,
      Customer? customer,
      Map<String, dynamic> businessInfo,
      Map<String, dynamic> invoiceSettings, {
        String templateType = 'traditional',
        Map<String, dynamic>? enhancedData,
        CreditSaleData? creditSaleData,
        String? printedBy,
      }) {
    final hasEnhancedData = enhancedData != null ||
        (order.lineItems.isNotEmpty && order.lineItems[0].containsKey('base_price'));

    if (hasEnhancedData) {
      return Invoice.fromEnhancedOrder(
        order,
        customer,
        businessInfo,
        invoiceSettings,
        templateType: templateType,
        enhancedData: enhancedData,
        creditSaleData: creditSaleData,
        printedBy: printedBy,
      );
    }

    final items = (order.lineItems).map((item) {
      return InvoiceItem(
        name: item['productName']?.toString() ?? 'Unknown Product',
        description: item['productSku']?.toString() ?? '',
        quantity: item['quantity'] ?? 1,
        unitPrice: (item['price'] as num?)?.toDouble() ?? 0.0,
        total: ((item['price'] as num?)?.toDouble() ?? 0.0) * (item['quantity'] ?? 1),
      );
    }).toList();

    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);

    final taxRate = (invoiceSettings['taxRate'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = subtotal * taxRate / 100;

    final discountRate = (invoiceSettings['discountRate'] as num?)?.toDouble() ?? 0.0;
    final discountAmount = subtotal * discountRate / 100;

    final totalAmount = subtotal + taxAmount - discountAmount;

    final isCreditSale = creditSaleData?.isCreditSale ?? false;
    final creditAmount = creditSaleData?.creditAmount;
    final paidAmount = creditSaleData?.paidAmount;
    final creditDueDate = creditSaleData?.dueDate;
    final previousBalance = creditSaleData?.previousBalance;
    final newBalance = creditSaleData?.newBalance;

    return Invoice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: order.id,
      invoiceNumber: 'INV-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${order.number}',
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(Duration(days: 30)),
      customer: customer,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      paymentMethod: order.lineItems.isNotEmpty ?
      (order.lineItems[0]['paymentMethod']?.toString() ?? 'cash') : 'cash',
      status: 'paid',
      notes: invoiceSettings['defaultNotes']?.toString() ?? 'Thank you for your business!',
      businessInfo: businessInfo,
      invoiceSettings: invoiceSettings,
      templateType: templateType,
      hasEnhancedPricing: false,
      isCreditSale: isCreditSale,
      creditAmount: creditAmount,
      paidAmount: paidAmount,
      creditDueDate: creditDueDate,
      previousBalance: previousBalance,
      newBalance: newBalance,
      creditSaleData: creditSaleData,
      printedBy: printedBy,
      printedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
      'id': id,
      'orderId': orderId,
      'invoiceNumber': invoiceNumber,
      'issueDate': issueDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'customer': customer?.toFirestore(),
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'notes': notes,
      'businessInfo': businessInfo,
      'invoiceSettings': invoiceSettings,
      'templateType': templateType,
      'isCreditSale': isCreditSale,
      'creditAmount': creditAmount,
      'paidAmount': paidAmount,
      'creditDueDate': creditDueDate?.toIso8601String(),
      'creditTerms': creditTerms,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'printedBy': printedBy,
      'printedAt': printedAt?.toIso8601String(),
    };

    if (hasEnhancedPricing && enhancedData != null) {
      data['enhancedData'] = enhancedData;
      data['hasEnhancedPricing'] = true;
    }

    if (creditSaleData != null) {
      data['creditSaleData'] = creditSaleData!.toMap();
    }

    return data;
  }

  factory Invoice.fromMap(Map<String, dynamic> data) {
    final items = (data['items'] as List).map((item) => InvoiceItem.fromMap(item)).toList();

    return Invoice(
      id: data['id'] ?? '',
      orderId: data['orderId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      issueDate: DateTime.parse(data['issueDate']),
      dueDate: data['dueDate'] != null ? DateTime.parse(data['dueDate']) : null,
      customer: data['customer'] != null ? Customer.fromFirestore(data['customer'], '') : null,
      items: items,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] ?? 'cash',
      status: data['status'] ?? 'paid',
      notes: data['notes'] ?? '',
      businessInfo: Map<String, dynamic>.from(data['businessInfo'] ?? {}),
      invoiceSettings: Map<String, dynamic>.from(data['invoiceSettings'] ?? {}),
      templateType: data['templateType'] ?? 'traditional',
      enhancedData: data['enhancedData'] != null ? Map<String, dynamic>.from(data['enhancedData']) : null,
      hasEnhancedPricing: data['hasEnhancedPricing'] ?? false,
      isCreditSale: data['isCreditSale'] ?? false,
      creditAmount: (data['creditAmount'] as num?)?.toDouble(),
      paidAmount: (data['paidAmount'] as num?)?.toDouble(),
      creditDueDate: data['creditDueDate'] != null ? DateTime.parse(data['creditDueDate']) : null,
      creditTerms: data['creditTerms'],
      previousBalance: (data['previousBalance'] as num?)?.toDouble(),
      newBalance: (data['newBalance'] as num?)?.toDouble(),
      creditSaleData: data['creditSaleData'] != null ?
      CreditSaleData.fromMap(Map<String, dynamic>.from(data['creditSaleData'])) : null,
      printedBy: data['printedBy'],
      printedAt: data['printedAt'] != null ? DateTime.parse(data['printedAt']) : null,
    );
  }

  Invoice copyWith({
    String? id,
    String? orderId,
    String? invoiceNumber,
    DateTime? issueDate,
    DateTime? dueDate,
    Customer? customer,
    List<InvoiceItem>? items,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? totalAmount,
    String? paymentMethod,
    String? status,
    String? notes,
    Map<String, dynamic>? businessInfo,
    Map<String, dynamic>? invoiceSettings,
    String? templateType,
    Map<String, dynamic>? enhancedData,
    bool? hasEnhancedPricing,
    bool? isCreditSale,
    double? creditAmount,
    double? paidAmount,
    DateTime? creditDueDate,
    String? creditTerms,
    double? previousBalance,
    double? newBalance,
    CreditSaleData? creditSaleData,
    String? printedBy,
    DateTime? printedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      businessInfo: businessInfo ?? this.businessInfo,
      invoiceSettings: invoiceSettings ?? this.invoiceSettings,
      templateType: templateType ?? this.templateType,
      enhancedData: enhancedData ?? this.enhancedData,
      hasEnhancedPricing: hasEnhancedPricing ?? this.hasEnhancedPricing,
      isCreditSale: isCreditSale ?? this.isCreditSale,
      creditAmount: creditAmount ?? this.creditAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      creditDueDate: creditDueDate ?? this.creditDueDate,
      creditTerms: creditTerms ?? this.creditTerms,
      previousBalance: previousBalance ?? this.previousBalance,
      newBalance: newBalance ?? this.newBalance,
      creditSaleData: creditSaleData ?? this.creditSaleData,
      printedBy: printedBy ?? this.printedBy,
      printedAt: printedAt ?? this.printedAt,
    );
  }
}

class InvoiceItem {
  final String name;
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;
  final double? basePrice;
  final double? manualDiscount;
  final double? manualDiscountPercent;
  final double? discountAmount;
  final double? baseSubtotal;
  final bool hasManualDiscount;

  InvoiceItem({
    required this.name,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.basePrice,
    this.manualDiscount,
    this.manualDiscountPercent,
    this.discountAmount,
    this.baseSubtotal,
    this.hasManualDiscount = false,
  });

  Map<String, dynamic> toMap() {
    final data = {
      'name': name,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };

    if (hasManualDiscount) {
      data.addAll({
        'basePrice': ?basePrice,
        'manualDiscount': ?manualDiscount,
        'manualDiscountPercent': ?manualDiscountPercent,
        'discountAmount': ?discountAmount,
        'baseSubtotal': ?baseSubtotal,
        'hasManualDiscount': true,
      });
    }

    return data;
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> data) {
    return InvoiceItem(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      quantity: data['quantity'] ?? 1,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      basePrice: (data['basePrice'] as num?)?.toDouble(),
      manualDiscount: (data['manualDiscount'] as num?)?.toDouble(),
      manualDiscountPercent: (data['manualDiscountPercent'] as num?)?.toDouble(),
      discountAmount: (data['discountAmount'] as num?)?.toDouble(),
      baseSubtotal: (data['baseSubtotal'] as num?)?.toDouble(),
      hasManualDiscount: data['hasManualDiscount'] ?? false,
    );
  }

  InvoiceItem copyWith({
    String? name,
    String? description,
    int? quantity,
    double? unitPrice,
    double? total,
    double? basePrice,
    double? manualDiscount,
    double? manualDiscountPercent,
    double? discountAmount,
    double? baseSubtotal,
    bool? hasManualDiscount,
  }) {
    return InvoiceItem(
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      basePrice: basePrice ?? this.basePrice,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      manualDiscountPercent: manualDiscountPercent ?? this.manualDiscountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      baseSubtotal: baseSubtotal ?? this.baseSubtotal,
      hasManualDiscount: hasManualDiscount ?? this.hasManualDiscount,
    );
  }
}