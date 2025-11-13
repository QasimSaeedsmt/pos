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

  // Logo support
  String? get logoPath => businessInfo['logoPath'] as String?;
  bool get includeLogo => invoiceSettings['includeLogo'] as bool? ?? true;

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

  // Enhanced factory method with detailed pricing
  factory Invoice.fromEnhancedOrder(
      AppOrder order,
      Customer? customer,
      Map<String, dynamic> businessInfo,
      Map<String, dynamic> invoiceSettings, {
        String templateType = 'traditional',
        Map<String, dynamic>? enhancedData,
      }) {
    print('DEBUG: Creating enhanced invoice with data: $enhancedData');

    // Use enhanced data if available, otherwise fall back to basic calculation
    if (enhancedData != null && enhancedData['cartData'] != null) {
      final cartData = enhancedData['cartData'] as Map<String, dynamic>;
      print('DEBUG: Cart data found: $cartData');

      return _createEnhancedInvoice(
        order,
        customer,
        businessInfo,
        invoiceSettings,
        templateType,
        enhancedData,
        cartData,
      );
    }

    print('DEBUG: No enhanced data, falling back to basic invoice');
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
      Map<String, dynamic> cartData,
      ) {
    print('DEBUG: Creating enhanced invoice with cart data');

    // Create enhanced items with discount information
    final enhancedItems = _createEnhancedItems(order.lineItems, enhancedData);

    // Calculate totals from cart data
    final subtotal = (cartData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (cartData['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (cartData['totalAmount'] as num?)?.toDouble() ?? 0.0;

    // Calculate total discount for backward compatibility
    final totalDiscount = (cartData['totalDiscount'] as num?)?.toDouble() ?? 0.0;

    print('DEBUG: Enhanced invoice totals - subtotal: $subtotal, tax: $taxAmount, total: $totalAmount, discount: $totalDiscount');

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
    final cartData = enhancedData['cartData'] as Map<String, dynamic>?;
    final enhancedLineItems = cartData?['line_items'] as List<dynamic>? ?? cartData?['items'] as List<dynamic>?;

    print('DEBUG: Creating enhanced items from ${lineItems.length} line items');
    print('DEBUG: Enhanced line items available: ${enhancedLineItems?.length ?? 0}');

    return lineItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final enhancedItem = enhancedLineItems != null && enhancedLineItems.length > index
          ? enhancedLineItems[index]
          : null;

      print('DEBUG: Processing item $index: ${item['productName']}');
      print('DEBUG: Enhanced item data: $enhancedItem');

      return InvoiceItem(
        name: item['productName']?.toString() ?? 'Unknown Product',
        description: item['productSku']?.toString() ?? '',
        quantity: (item['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (item['price'] as num?)?.toDouble() ?? 0.0,
        total: (enhancedItem?['final_subtotal'] as num?)?.toDouble() ??
            (enhancedItem?['subtotal'] as num?)?.toDouble() ??
            ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1),
        // Enhanced fields
        basePrice: (enhancedItem?['base_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble(),
        manualDiscount: (enhancedItem?['manual_discount'] as num?)?.toDouble() ?? (enhancedItem?['manualDiscount'] as num?)?.toDouble(),
        manualDiscountPercent: (enhancedItem?['manual_discount_percent'] as num?)?.toDouble() ?? (enhancedItem?['manualDiscountPercent'] as num?)?.toDouble(),
        discountAmount: (enhancedItem?['discount_amount'] as num?)?.toDouble() ?? (enhancedItem?['discountAmount'] as num?)?.toDouble(),
        baseSubtotal: (enhancedItem?['base_subtotal'] as num?)?.toDouble() ?? (enhancedItem?['baseSubtotal'] as num?)?.toDouble(),
        hasManualDiscount: enhancedItem?['has_manual_discount'] ?? enhancedItem?['hasManualDiscount'] ?? false,
      );
    }).toList();
  }

  // COMPLETE DISCOUNT CALCULATIONS - INDEPENDENT OF SETTINGS
  double get totalItemDiscounts {
    if (hasEnhancedPricing) {
      return items.fold(0.0, (sum, item) => sum + (item.discountAmount ?? 0.0));
    }
    return discountAmount; // Fallback to legacy discount
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

  // Get all applied discounts independently
  Map<String, double> get allDiscounts {
    final discounts = <String, double>{};

    if (hasEnhancedPricing) {
      // Item-level discounts
      discounts['item_discounts'] = totalItemDiscounts;

      // Cart-level discounts
      discounts['cart_discount'] = cartDiscountAmount;

      // Additional discounts
      discounts['additional_discount'] = additionalDiscountAmount;

      // Settings-based discount (for backward compatibility)
      final settingsDiscountRate = (invoiceSettings['discountRate'] as num?)?.toDouble() ?? 0.0;
      final settingsDiscount = subtotal * settingsDiscountRate / 100;
      discounts['settings_discount'] = settingsDiscount;
    } else {
      // Legacy discount calculation
      discounts['legacy_discount'] = discountAmount;
    }

    return discounts;
  }

  // Enhanced display flags
  bool get showCustomerDetails => customer != null && (invoiceSettings['includeCustomerDetails'] ?? true);

  bool get showItemDiscounts => hasEnhancedPricing && items.any((item) => item.hasManualDiscount);

  bool get showCartDiscount => hasEnhancedPricing && cartDiscountAmount > 0;

  bool get showAdditionalDiscount => hasEnhancedPricing && additionalDiscountAmount > 0;

  bool get showShipping => hasEnhancedPricing && shippingAmount > 0;

  bool get showTip => hasEnhancedPricing && tipAmount > 0;

  // Get enhanced pricing breakdown
  Map<String, dynamic>? get pricingBreakdown => hasEnhancedPricing
      ? enhancedData?['cartData']?['pricing_breakdown'] as Map<String, dynamic>?
      : null;

  double get shippingAmount => hasEnhancedPricing
      ? (enhancedData?['shippingAmount'] as num? ?? 0.0).toDouble()
      : 0.0;

  double get tipAmount => hasEnhancedPricing
      ? (enhancedData?['tipAmount'] as num? ?? 0.0).toDouble()
      : 0.0;

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

    // Calculate discounts independently from settings
    final taxRate = (invoiceSettings['taxRate'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = subtotal * taxRate / 100;

    // For legacy invoices, we only use the settings discount
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