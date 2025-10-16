import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
    }

    return Sale(
      id: doc.id,
      tenantId: data['tenantId']?.toString() ?? '',
      cashierId: data['cashierId']?.toString() ?? '',
      cashierName: data['cashierName']?.toString() ?? 'Unknown Cashier',
      cashierEmail: data['cashierEmail']?.toString() ?? '',
      items: items,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod']?.toString() ?? 'cash',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status']?.toString() ?? 'completed',
      customerName: data['customerName']?.toString(),
      customerEmail: data['customerEmail']?.toString(),
      customerPhone: data['customerPhone']?.toString(),
      notes: data['notes']?.toString(),
    );
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
    return SaleItem(
      productId: map['productId']?.toString() ?? '',
      productName: map['name']?.toString() ?? 'Unknown Product',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toDouble() ??
          ((map['price'] as num?)?.toDouble() ?? 0.0) * ((map['quantity'] as num?)?.toInt() ?? 0),
    );
  }
}