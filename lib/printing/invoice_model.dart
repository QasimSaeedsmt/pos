import '../app.dart';
import '../features/customerBase/customer_base.dart';
import '../features/orderBase/order_base.dart';

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

  // Enhanced fields - optional for backward compatibility
  final Map<String, dynamic>? enhancedData;
  final bool hasEnhancedPricing;

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
  });

  // Original factory method - preserved for backward compatibility
  factory Invoice.fromOrder(AppOrder order, Customer? customer,
      Map<String, dynamic> businessInfo, Map<String, dynamic> invoiceSettings,
      {String templateType = 'traditional'}) {

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
    );
  }

  // Enhanced factory method with detailed pricing
  factory Invoice.fromEnhancedOrder(
      AppOrder order,
      Customer? customer,
      Map<String, dynamic> businessInfo,
      Map<String, dynamic> invoiceSettings, {
        String templateType = 'traditional',
        Map<String, dynamic>? enhancedData,
      }) {
    // Use enhanced data if available, otherwise fall back to basic calculation
    if (enhancedData != null && enhancedData['cartData'] != null) {
      final cartData = enhancedData['cartData'] as Map<String, dynamic>;
      final pricingBreakdown = cartData['pricing_breakdown'] as Map<String, dynamic>?;

      if (pricingBreakdown != null) {
        return _createEnhancedInvoice(
          order,
          customer,
          businessInfo,
          invoiceSettings,
          templateType,
          enhancedData,
          pricingBreakdown,
        );
      }
    }

    // Fallback to original method if no enhanced data
    return Invoice.fromOrder(order, customer, businessInfo, invoiceSettings, templateType: templateType);
  }

  static Invoice _createEnhancedInvoice(
      AppOrder order,
      Customer? customer,
      Map<String, dynamic> businessInfo,
      Map<String, dynamic> invoiceSettings,
      String templateType,
      Map<String, dynamic> enhancedData,
      Map<String, dynamic> pricingBreakdown,
      ) {
    // Create enhanced items with discount information
    final enhancedItems = _createEnhancedItems(order.lineItems, enhancedData);

    final subtotal = (pricingBreakdown['subtotal'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (pricingBreakdown['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final totalDiscount = (pricingBreakdown['total_discount'] as num?)?.toDouble() ?? 0.0;
    final finalTotal = (pricingBreakdown['final_total'] as num?)?.toDouble() ?? subtotal + taxAmount;

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
      totalAmount: finalTotal,
      paymentMethod: enhancedData['paymentMethod']?.toString() ?? 'cash',
      status: 'paid',
      notes: invoiceSettings['defaultNotes']?.toString() ?? 'Thank you for your business!',
      businessInfo: businessInfo,
      invoiceSettings: invoiceSettings,
      templateType: templateType,
      enhancedData: enhancedData,
      hasEnhancedPricing: true,
    );
  }

  static List<InvoiceItem> _createEnhancedItems(List<dynamic> lineItems, Map<String, dynamic> enhancedData) {
    final enhancedLineItems = enhancedData['cartData']?['line_items'] as List<dynamic>?;

    return lineItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final enhancedItem = enhancedLineItems != null && enhancedLineItems.length > index
          ? enhancedLineItems[index]
          : null;

      return InvoiceItem(
        name: item['productName']?.toString() ?? 'Unknown Product',
        description: item['productSku']?.toString() ?? '',
        quantity: item['quantity'] ?? 1,
        unitPrice: (item['price'] as num?)?.toDouble() ?? 0.0,
        total: (enhancedItem?['final_subtotal'] as num?)?.toDouble() ??
            ((item['price'] as num?)?.toDouble() ?? 0.0) * (item['quantity'] ?? 1),
        // Enhanced fields
        basePrice: (enhancedItem?['base_price'] as num?)?.toDouble(),
        manualDiscount: (enhancedItem?['manual_discount'] as num?)?.toDouble(),
        manualDiscountPercent: (enhancedItem?['manual_discount_percent'] as num?)?.toDouble(),
        discountAmount: (enhancedItem?['discount_amount'] as num?)?.toDouble(),
        baseSubtotal: (enhancedItem?['base_subtotal'] as num?)?.toDouble(),
        hasManualDiscount: enhancedItem?['has_manual_discount'] ?? false,
      );
    }).toList();
  }

  // Enhanced getters for conditional display
  bool get showCustomerDetails => customer != null && (invoiceSettings['includeCustomerDetails'] ?? true);

  bool get showItemDiscounts => hasEnhancedPricing &&
      items.any((item) => item.hasManualDiscount);

  bool get showCartDiscount => hasEnhancedPricing &&
      (enhancedData?['cartData']?['pricing_breakdown']?['cart_discount_amount'] as num? ?? 0) > 0;

  bool get showAdditionalDiscount => hasEnhancedPricing &&
      (enhancedData?['additionalDiscount'] as num? ?? 0) > 0;

  bool get showShipping => hasEnhancedPricing &&
      (enhancedData?['shippingAmount'] as num? ?? 0) > 0;

  bool get showTip => hasEnhancedPricing &&
      (enhancedData?['tipAmount'] as num? ?? 0) > 0;

  // Get enhanced pricing breakdown
  Map<String, dynamic>? get pricingBreakdown => hasEnhancedPricing
      ? enhancedData?['cartData']?['pricing_breakdown'] as Map<String, dynamic>?
      : null;

  double get cartDiscountAmount => hasEnhancedPricing
      ? (pricingBreakdown?['cart_discount_amount'] as num? ?? 0).toDouble()
      : 0.0;

  double get additionalDiscount => hasEnhancedPricing
      ? (enhancedData?['additionalDiscount'] as num? ?? 0).toDouble()
      : 0.0;

  double get shippingAmount => hasEnhancedPricing
      ? (enhancedData?['shippingAmount'] as num? ?? 0).toDouble()
      : 0.0;

  double get tipAmount => hasEnhancedPricing
      ? (enhancedData?['tipAmount'] as num? ?? 0).toDouble()
      : 0.0;

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
    };

    // Add enhanced data if available
    if (hasEnhancedPricing && enhancedData != null) {
      data['enhancedData'] = enhancedData;
      data['hasEnhancedPricing'] = true;
    }

    return data;
  }

  // Backward compatibility - create from map
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
    );
  }

  // Copy with method for creating modified instances
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
    );
  }
}

class InvoiceItem {
  final String name;
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  // Enhanced fields - optional
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

    // Add enhanced fields if available
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

  // Copy with method
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