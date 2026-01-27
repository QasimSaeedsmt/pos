import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../features/main_navigation/main_navigation_base.dart';
import 'customer_model.dart';

part 'app_order_model.g.dart';

@HiveType(typeId: 9)
class AppOrder {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String number;

  @HiveField(2)
  final DateTime dateCreated;

  @HiveField(3)
  final double total;

  @HiveField(4)
  final List<dynamic> lineItems;

  @HiveField(5)
  final String? customerId;

  @HiveField(6)
  final String? customerName;

  @HiveField(7)
  final String? customerEmail;

  @HiveField(8)
  final String? customerPhone;

  @HiveField(9)
  final String? customerAddress;

  @HiveField(10)
  final Map<String, dynamic>? customerData;

  AppOrder({
    required this.id,
    required this.number,
    required this.dateCreated,
    required this.total,
    required this.lineItems,
    this.customerId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.customerAddress,
    this.customerData,
  });

  factory AppOrder.fromFirestore(Map<String, dynamic> data, String id) {
    final customerInfo = (data['customer'] is Map)
        ? Map<String, dynamic>.from(data['customer'])
        : <String, dynamic>{};

    final enhancedData = (data['enhancedData'] is Map)
        ? Map<String, dynamic>.from(data['enhancedData'])
        : <String, dynamic>{};

    return AppOrder(
      id: id,
      number: data['number'] ?? '',
      dateCreated: data['dateCreated'] is Timestamp
          ? (data['dateCreated'] as Timestamp).toDate()
          : DateTime.now(),
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      lineItems: data['lineItems'] ?? [],

      customerId: data['customerId']?.toString() ?? customerInfo['id']?.toString(),
      customerName: _extractCustomerName(
        data,
        customerInfo,
        enhancedData,
      ),
      customerEmail: data['customerEmail']?.toString() ?? customerInfo['email']?.toString(),
      customerPhone: data['customerPhone']?.toString() ?? customerInfo['phone']?.toString(),
      customerAddress: data['customerAddress']?.toString() ?? customerInfo['address']?.toString(),
      customerData: customerInfo.isNotEmpty ? customerInfo : null,
    );
  }

  static String? _extractCustomerName(Map<String, dynamic> data, Map<String, dynamic> customerInfo, Map<String, dynamic> enhancedData) {
    // Priority 1: Direct customer name fields
    if (data['customerName'] != null && data['customerName'].toString().isNotEmpty) {
      return data['customerName'].toString();
    }

    // Priority 2: Customer info map
    if (customerInfo['firstName'] != null || customerInfo['lastName'] != null) {
      final firstName = customerInfo['firstName']?.toString() ?? '';
      final lastName = customerInfo['lastName']?.toString() ?? '';
      return '$firstName $lastName'.trim();
    }

    // Priority 3: Customer info from enhanced data
    final enhancedCustomer = enhancedData['customerInfo'] is Map ? enhancedData['customerInfo'] as Map<String, dynamic> : {};
    if (enhancedCustomer['name'] != null && enhancedCustomer['name'].toString().isNotEmpty) {
      return enhancedCustomer['name'].toString();
    }

    // Priority 4: Full name from enhanced data
    if (enhancedCustomer['firstName'] != null || enhancedCustomer['lastName'] != null) {
      final firstName = enhancedCustomer['firstName']?.toString() ?? '';
      final lastName = enhancedCustomer['lastName']?.toString() ?? '';
      return '$firstName $lastName'.trim();
    }

    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'number': number,
      'dateCreated': Timestamp.fromDate(dateCreated),
      'total': total,
      'lineItems': lineItems,
      // Include customer data at order level
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customer': customerData,
      // Add additional fields that might be stored in your Firestore orders
      'subtotal': calculateSubtotal(),
      'totalDiscount': calculateTotalDiscount(),
      'itemDiscounts': calculateItemDiscounts(),
      'cartDiscount': calculateCartDiscount(),
      'additionalDiscount': calculateAdditionalDiscount(),
      'taxAmount': calculateTaxAmount(),
      'shippingAmount': calculateShippingAmount(),
      'tipAmount': calculateTipAmount(),
      'taxableAmount': calculateTaxableAmount(),
      'paymentMethod': getPaymentMethod(),
    };
  }

  // CORRECTED CUSTOMER METHODS - Get data from order level, not line items
  String get customerDisplayName {
    // First try to get from order-level customer data
    if (customerName != null && customerName!.isNotEmpty && customerName != 'null') {
      return customerName!;
    }

    // Fallback: check customer data map
    if (customerData != null) {
      final firstName = customerData!['firstName']?.toString() ?? '';
      final lastName = customerData!['lastName']?.toString() ?? '';
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) {
        return fullName;
      }

      final nameFromData = customerData!['name']?.toString();
      if (nameFromData != null && nameFromData.isNotEmpty && nameFromData != 'null') {
        return nameFromData;
      }
    }

    // Final fallback: check line items (for backward compatibility only)
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        final customerName = item['customerName']?.toString() ??
            item['customer_name']?.toString();
        if (customerName != null && customerName.isNotEmpty && customerName != 'null') {
          return customerName;
        }
      }
    }

    return 'Walk-in Customer';
  }

  String get customerContactInfo {
    final contactInfo = <String>[];

    // First try order-level contact info
    if (customerEmail != null && customerEmail!.isNotEmpty && customerEmail != 'null') {
      contactInfo.add(customerEmail!);
    }
    if (customerPhone != null && customerPhone!.isNotEmpty && customerPhone != 'null') {
      contactInfo.add(customerPhone!);
    }

    // Then try customer data map
    if (contactInfo.isEmpty && customerData != null) {
      final email = customerData!['email']?.toString();
      if (email != null && email.isNotEmpty && email != 'null' && !contactInfo.contains(email)) {
        contactInfo.add(email);
      }

      final phone = customerData!['phone']?.toString();
      if (phone != null && phone.isNotEmpty && phone != 'null' && !contactInfo.contains(phone)) {
        contactInfo.add(phone);
      }
    }

    // If still no contact info, check line items
    if (contactInfo.isEmpty) {
      for (var item in lineItems) {
        if (item is Map<String, dynamic>) {
          final email = item['customerEmail']?.toString() ??
              item['customer_email']?.toString();
          if (email != null && email.isNotEmpty && email != 'null' && !contactInfo.contains(email)) {
            contactInfo.add(email);
          }

          final phone = item['customerPhone']?.toString() ??
              item['customer_phone']?.toString();
          if (phone != null && phone.isNotEmpty && phone != 'null' && !contactInfo.contains(phone)) {
            contactInfo.add(phone);
          }
        }
      }
    }

    return contactInfo.isNotEmpty ? contactInfo.join(' • ') : 'No contact information';
  }

  String get customerDetailedInfo {
    final details = <String>[];

    final name = customerDisplayName;
    final contact = customerContactInfo;

    if (name != 'Walk-in Customer') {
      details.add(name);
    }
    if (contact != 'No contact information') {
      details.add(contact);
    }

    // Check for address information from order level
    if (customerAddress != null && customerAddress!.isNotEmpty && customerAddress != 'null') {
      details.add(customerAddress!);
    } else if (customerData != null) {
      // Check customer data map for address
      final address = customerData!['address']?.toString() ??
          customerData!['address1']?.toString();
      if (address != null && address.isNotEmpty && address != 'null' && !details.contains(address)) {
        details.add(address);
      }
    } else {
      // Final fallback to line items
      for (var item in lineItems) {
        if (item is Map<String, dynamic>) {
          final address = item['customerAddress']?.toString() ??
              item['customer_address']?.toString();
          if (address != null && address.isNotEmpty && address != 'null' && !details.contains(address)) {
            details.add(address);
          }
        }
      }
    }

    return details.isNotEmpty ? details.join('\n') : 'Walk-in Customer';
  }

  // Add method to check if order has real customer data
  bool get hasRealCustomerData {
    return customerName != null &&
        customerName!.isNotEmpty &&
        customerName != 'null' &&
        customerName != 'Walk-in Customer';
  }

  bool get hasCustomerId {
    return customerId != null && customerId!.isNotEmpty && customerId != 'null';
  }

  // Method to get customer for lookup
  Future<Customer?> getCustomer(EnhancedPOSService posService) async {
    if (customerId != null && customerId!.isNotEmpty) {
      try {
        // Try to fetch customer by ID
        final customer = await posService.getCustomerById(customerId!);
        return customer;
      } catch (e) {
        debugPrint('Error fetching customer by ID: $e');
      }
    }

    // If no customer ID or fetch failed, return null
    return null;
  }

  // Helper methods to calculate financial values
  double calculateSubtotal() {
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

  double calculateTotalDiscount() {
    double totalDiscount = 0.0;

    // Item-level discounts
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        final discount = (item['discountAmount'] as num?)?.toDouble() ?? 0.0;
        totalDiscount += discount;
      }
    }

    return totalDiscount;
  }

  double calculateItemDiscounts() {
    double itemDiscounts = 0.0;
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        final discount = (item['discountAmount'] as num?)?.toDouble() ?? 0.0;
        itemDiscounts += discount;
      }
    }
    return itemDiscounts;
  }

  double calculateCartDiscount() {
    // Check multiple data sources in order of priority

    // 1. First check enhancedData in customerData
    if (customerData != null && customerData!.containsKey('enhancedData')) {
      final enhancedData = Map<String, dynamic>.from(customerData!['enhancedData']);

      // Try cartData in enhancedData
      if (enhancedData['cartData'] != null) {
        final cartData = Map<String, dynamic>.from(enhancedData['cartData']);
        if (cartData.containsKey('cart_discount_amount')) {
          return (cartData['cart_discount_amount'] as num?)?.toDouble() ?? 0.0;
        }
        if (cartData.containsKey('cartDiscount')) {
          return (cartData['cartDiscount'] as num?)?.toDouble() ?? 0.0;
        }
        if (cartData.containsKey('cart_discount')) {
          return (cartData['cart_discount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // Try direct fields in enhancedData
      if (enhancedData.containsKey('cartDiscount')) {
        return (enhancedData['cartDiscount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // 2. Check if there's a pricingBreakdown field at the order level
    // This is set in FirestoreServices.createOrderWithEnhancedData()
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        if (item.containsKey('pricingBreakdown')) {
          final pricing = Map<String, dynamic>.from(item['pricingBreakdown']);
          if (pricing.containsKey('cartDiscount')) {
            return (pricing['cartDiscount'] as num?)?.toDouble() ?? 0.0;
          }
          if (pricing.containsKey('cartDiscountAmount')) {
            return (pricing['cartDiscountAmount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }

    return 0.0;
  }

  double calculateAdditionalDiscount() {
    // Check multiple data sources for additional discount

    // 1. Check enhancedData
    if (customerData != null && customerData!.containsKey('enhancedData')) {
      final enhancedData = Map<String, dynamic>.from(customerData!['enhancedData']);

      if (enhancedData.containsKey('additionalDiscount')) {
        return (enhancedData['additionalDiscount'] as num?)?.toDouble() ?? 0.0;
      }

      // Check in cartData
      if (enhancedData['cartData'] != null) {
        final cartData = Map<String, dynamic>.from(enhancedData['cartData']);
        if (cartData.containsKey('additional_discount')) {
          return (cartData['additional_discount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    // 2. Check for additional discount in line items
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        if (item.containsKey('additionalDiscount')) {
          return (item['additionalDiscount'] as num?)?.toDouble() ?? 0.0;
        }

        // Check in pricing breakdown
        if (item.containsKey('pricingBreakdown')) {
          final pricing = Map<String, dynamic>.from(item['pricingBreakdown']);
          if (pricing.containsKey('additionalDiscount')) {
            return (pricing['additionalDiscount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }

    return 0.0;
  }

  double calculateShippingAmount() {
    // Shipping amount is typically stored in enhancedData

    // 1. Check enhancedData
    if (customerData != null && customerData!.containsKey('enhancedData')) {
      final enhancedData = Map<String, dynamic>.from(customerData!['enhancedData']);

      if (enhancedData.containsKey('shippingAmount')) {
        return (enhancedData['shippingAmount'] as num?)?.toDouble() ?? 0.0;
      }

      // Check in cartData
      if (enhancedData['cartData'] != null) {
        final cartData = Map<String, dynamic>.from(enhancedData['cartData']);
        if (cartData.containsKey('shipping_amount')) {
          return (cartData['shipping_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    // 2. Check line items for shipping
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        if (item.containsKey('shippingAmount')) {
          return (item['shippingAmount'] as num?)?.toDouble() ?? 0.0;
        }

        // Check in pricing breakdown
        if (item.containsKey('pricingBreakdown')) {
          final pricing = Map<String, dynamic>.from(item['pricingBreakdown']);
          if (pricing.containsKey('shippingAmount')) {
            return (pricing['shippingAmount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }

    return 0.0;
  }

  double calculateTipAmount() {
    // Tip amount is typically stored in enhancedData

    // 1. Check enhancedData
    if (customerData != null && customerData!.containsKey('enhancedData')) {
      final enhancedData = Map<String, dynamic>.from(customerData!['enhancedData']);

      if (enhancedData.containsKey('tipAmount')) {
        return (enhancedData['tipAmount'] as num?)?.toDouble() ?? 0.0;
      }

      // Check in cartData
      if (enhancedData['cartData'] != null) {
        final cartData = Map<String, dynamic>.from(enhancedData['cartData']);
        if (cartData.containsKey('tip_amount')) {
          return (cartData['tip_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    // 2. Check line items for tip
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        if (item.containsKey('tipAmount')) {
          return (item['tipAmount'] as num?)?.toDouble() ?? 0.0;
        }

        // Check in pricing breakdown
        if (item.containsKey('pricingBreakdown')) {
          final pricing = Map<String, dynamic>.from(item['pricingBreakdown']);
          if (pricing.containsKey('tipAmount')) {
            return (pricing['tipAmount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }

    return 0.0;
  }
  double calculateTaxAmount() {
    // Get tax from enhancedData or calculate from taxable amount

    // 1. Try to get tax amount directly from enhancedData
    if (customerData != null && customerData!.containsKey('enhancedData')) {
      final enhancedData = Map<String, dynamic>.from(customerData!['enhancedData']);

      if (enhancedData['cartData'] != null) {
        final cartData = Map<String, dynamic>.from(enhancedData['cartData']);
        if (cartData.containsKey('tax_amount')) {
          return (cartData['tax_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    // 2. Calculate tax using stored tax rate
    const defaultTaxRate = 0.0; // Change this to your default tax rate

    // Try to find tax rate in enhancedData
    double taxRate = defaultTaxRate;
    if (customerData != null && customerData!.containsKey('enhancedData')) {
      final enhancedData = Map<String, dynamic>.from(customerData!['enhancedData']);
      if (enhancedData['cartData'] != null) {
        final cartData = Map<String, dynamic>.from(enhancedData['cartData']);
        taxRate = (cartData['tax_rate'] as num?)?.toDouble() ?? defaultTaxRate;
      }
    }

    final taxableAmount = calculateTaxableAmount();
    return taxableAmount * taxRate;
  }



  double calculateTaxableAmount() {
    final subtotal = calculateSubtotal();
    final discounts = calculateTotalDiscount();
    return subtotal - discounts;
  }

  String getPaymentMethod() {
    return 'cash';
  }

  int get totalItems {
    int count = 0;
    for (var item in lineItems) {
      if (item is Map<String, dynamic>) {
        count += (item['quantity'] as num?)?.toInt() ?? 1;
      }
    }
    return count;
  }

  Map<String, dynamic> extractEnhancedData() {
    return {
      'cartData': {
        'subtotal': calculateSubtotal(),
        'totalDiscount': calculateTotalDiscount(),
        'taxAmount': calculateTaxAmount(),
        'shippingAmount': calculateShippingAmount(),
        'tipAmount': calculateTipAmount(),
        'finalTotal': total,
        'pricing_breakdown': {
          'subtotal': calculateSubtotal(),
          'item_discounts': calculateItemDiscounts(),
          'cart_discount_amount': calculateCartDiscount(),
          'additional_discount_amount': calculateAdditionalDiscount(),
          'total_discount': calculateTotalDiscount(),
          'taxable_amount': calculateTaxableAmount(),
          'tax_amount': calculateTaxAmount(),
          'shipping_amount': calculateShippingAmount(),
          'tip_amount': calculateTipAmount(),
          'grand_total': total,
        }
      },
      'paymentMethod': getPaymentMethod(),
      'additionalDiscount': calculateAdditionalDiscount(),
      'shippingAmount': calculateShippingAmount(),
      'tipAmount': calculateTipAmount(),
      'customerInfo': {
        'name': customerDisplayName,
        'contact': customerContactInfo,
        'detailedInfo': customerDetailedInfo,
        'hasRealData': hasRealCustomerData,
        'customerId': customerId,
      },
    };
  }

  // Simple status for basic functionality
  String get statusDisplay {
    return 'Completed';
  }

  Color get statusColor {
    return Colors.green;
  }

  IconData get statusIcon {
    return Icons.check_circle;
  }

  // Debug method to see what customer data is available
  void printCustomerData() {
    debugPrint('=== Customer Data for Order $number ===');
    debugPrint('Order Level Customer Data:');
    debugPrint('  - Customer ID: $customerId');
    debugPrint('  - Customer Name: $customerName');
    debugPrint('  - Customer Email: $customerEmail');
    debugPrint('  - Customer Phone: $customerPhone');
    debugPrint('  - Customer Address: $customerAddress');
    debugPrint('  - Customer Data Map: $customerData');
    debugPrint('Detected Customer: $customerDisplayName');
    debugPrint('Contact Info: $customerContactInfo');
    debugPrint('Has Real Customer Data: $hasRealCustomerData');
    debugPrint('================================');
  }
}