import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';

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

class AppOrder {
  final String id;
  final String number;
  final DateTime dateCreated;
  final double total;
  final List<dynamic> lineItems;

  AppOrder({
    required this.id,
    required this.number,
    required this.dateCreated,
    required this.total,
    required this.lineItems,
  });

  factory AppOrder.fromFirestore(Map<String, dynamic> data, String id) {
    return AppOrder(
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
      'itemDiscounts': calculateItemDiscounts(),
      'cartDiscount': calculateCartDiscount(),
      'additionalDiscount': calculateAdditionalDiscount(),
      'taxAmount': calculateTaxAmount(),
      'shippingAmount': calculateShippingAmount(),
      'tipAmount': calculateTipAmount(),
      'taxableAmount': calculateTaxableAmount(),
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
    // This would return cart-level discounts
    // You might need to store this separately in your order data
    return 0.0; // Replace with actual cart discount calculation
  }

  double calculateAdditionalDiscount() {
    // This would return additional discounts applied at checkout
    // You might need to store this separately in your order data
    return 0.0; // Replace with actual additional discount calculation
  }

  double calculateTaxAmount() {
    // Calculate tax amount based on your business logic
    // This might be stored separately or calculated from taxable amount and tax rate
    final subtotal = _calculateSubtotal();
    final discounts = _calculateTotalDiscount();
    final taxableAmount = subtotal - discounts;

    // Assuming a default tax rate of 10% - adjust based on your needs
    const taxRate = 0.10;
    return taxableAmount * taxRate;
  }

  double calculateShippingAmount() {
    // Return shipping amount if stored in order data
    return 0.0; // Replace with actual shipping amount
  }

  double calculateTipAmount() {
    // Return tip amount if stored in order data
    return 0.0; // Replace with actual tip amount
  }

  double calculateTaxableAmount() {
    final subtotal = _calculateSubtotal();
    final discounts = _calculateTotalDiscount();
    return subtotal - discounts;
  }

  String _getPaymentMethod() {
    // Return payment method if stored in order data
    return 'cash'; // Replace with actual payment method from order data
  }
}
