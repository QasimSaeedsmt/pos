import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../customerBase/customer_base.dart';
import '../main_navigation/main_navigation_base.dart';

class OrderCard extends StatelessWidget {
  final AppOrder order;
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
// order_status.dart

enum OrderStatus {
  all,
  pending,
  confirmed,
  processing,
  ready,
  completed,
  cancelled,
  refunded,
  onHold,
  failed,
  partiallyRefunded
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.all:
        return 'All Orders';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.onHold:
        return 'On Hold';
      case OrderStatus.failed:
        return 'Failed';
      case OrderStatus.partiallyRefunded:
        return 'Partially Refunded';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.all:
        return 'All orders regardless of status';
      case OrderStatus.pending:
        return 'Order received but payment pending';
      case OrderStatus.confirmed:
        return 'Payment confirmed, preparing order';
      case OrderStatus.processing:
        return 'Order is being processed';
      case OrderStatus.ready:
        return 'Order is ready for pickup/delivery';
      case OrderStatus.completed:
        return 'Order successfully delivered/fulfilled';
      case OrderStatus.cancelled:
        return 'Order was cancelled';
      case OrderStatus.refunded:
        return 'Order was fully refunded';
      case OrderStatus.onHold:
        return 'Order placed on hold';
      case OrderStatus.failed:
        return 'Order processing failed';
      case OrderStatus.partiallyRefunded:
        return 'Order was partially refunded';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.all:
        return Colors.grey;
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.lightBlue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.purple;
      case OrderStatus.onHold:
        return Colors.amber;
      case OrderStatus.failed:
        return Colors.red;
      case OrderStatus.partiallyRefunded:
        return Colors.deepPurple;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.all:
        return Icons.list_alt;
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.verified;
      case OrderStatus.processing:
        return Icons.autorenew;
      case OrderStatus.ready:
        return Icons.assignment_turned_in;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
      case OrderStatus.onHold:
        return Icons.pause_circle;
      case OrderStatus.failed:
        return Icons.error;
      case OrderStatus.partiallyRefunded:
        return Icons.payment;
    }
  }

  int get priority {
    switch (this) {
      case OrderStatus.pending:
        return 1;
      case OrderStatus.confirmed:
        return 2;
      case OrderStatus.processing:
        return 3;
      case OrderStatus.ready:
        return 4;
      case OrderStatus.completed:
        return 5;
      case OrderStatus.onHold:
        return 6;
      case OrderStatus.partiallyRefunded:
        return 7;
      case OrderStatus.refunded:
        return 8;
      case OrderStatus.cancelled:
        return 9;
      case OrderStatus.failed:
        return 10;
      case OrderStatus.all:
        return 0;
    }
  }

  bool get isActive {
    return this == OrderStatus.pending ||
        this == OrderStatus.confirmed ||
        this == OrderStatus.processing ||
        this == OrderStatus.ready ||
        this == OrderStatus.onHold;
  }

  bool get isCompleted {
    return this == OrderStatus.completed;
  }

  bool get isCancelled {
    return this == OrderStatus.cancelled || this == OrderStatus.failed;
  }

  bool get isRefunded {
    return this == OrderStatus.refunded || this == OrderStatus.partiallyRefunded;
  }
}

class OrderStatusUtils {
  static List<OrderStatus> get activeStatuses {
    return [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.processing,
      OrderStatus.ready,
      OrderStatus.onHold,
    ];
  }

  static List<OrderStatus> get completedStatuses {
    return [
      OrderStatus.completed,
    ];
  }

  static List<OrderStatus> get cancelledStatuses {
    return [
      OrderStatus.cancelled,
      OrderStatus.failed,
    ];
  }

  static List<OrderStatus> get refundStatuses {
    return [
      OrderStatus.refunded,
      OrderStatus.partiallyRefunded,
    ];
  }

  static List<OrderStatus> get filterableStatuses {
    return OrderStatus.values.where((status) => status != OrderStatus.all).toList();
  }

  static OrderStatus fromString(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      case 'onhold':
      case 'on_hold':
        return OrderStatus.onHold;
      case 'failed':
        return OrderStatus.failed;
      case 'partially_refunded':
      case 'partiallyrefunded':
        return OrderStatus.partiallyRefunded;
      default:
        return OrderStatus.pending;
    }
  }

  static String toFirestoreValue(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.onHold:
        return 'onHold';
      case OrderStatus.failed:
        return 'failed';
      case OrderStatus.partiallyRefunded:
        return 'partiallyRefunded';
      case OrderStatus.all:
        return 'all';
    }
  }

  static OrderStatus fromFirestoreValue(String value) {
    return fromString(value);
  }
}


class AppOrder {
  final String id;
  final String number;
  final DateTime dateCreated;
  final double total;
  final List<dynamic> lineItems;

  // Add direct customer fields
  final String? customerId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerAddress;
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
        print('Error fetching customer by ID: $e');
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
    return 0.0;
  }

  double calculateAdditionalDiscount() {
    return 0.0;
  }

  double calculateTaxAmount() {
    final subtotal = calculateSubtotal();
    final discounts = calculateTotalDiscount();
    final taxableAmount = subtotal - discounts;

    const taxRate = 0.0;
    return taxableAmount * taxRate;
  }

  double calculateShippingAmount() {
    return 0.0;
  }

  double calculateTipAmount() {
    return 0.0;
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
    print('=== Customer Data for Order ${number} ===');
    print('Order Level Customer Data:');
    print('  - Customer ID: $customerId');
    print('  - Customer Name: $customerName');
    print('  - Customer Email: $customerEmail');
    print('  - Customer Phone: $customerPhone');
    print('  - Customer Address: $customerAddress');
    print('  - Customer Data Map: $customerData');
    print('Detected Customer: ${customerDisplayName}');
    print('Contact Info: ${customerContactInfo}');
    print('Has Real Customer Data: $hasRealCustomerData');
    print('================================');
  }
}