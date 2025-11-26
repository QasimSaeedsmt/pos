// New file: credit_models.dart
import 'package:intl/intl.dart';
class ProductDetail {
  final String productId;
  final String productName;
  final String? productDescription;
  final String? productCategory;
  final String? sku;
  final double unitPrice;
  final int quantity;
  final double totalPrice;
  final String? unitType;
  final double? discount;
  final double? taxAmount;

  ProductDetail({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
    this.productDescription,
    this.productCategory,
    this.sku,
    this.unitType,
    this.discount,
    this.taxAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productDescription': productDescription,
      'productCategory': productCategory,
      'sku': sku,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'unitType': unitType,
      'discount': discount,
      'taxAmount': taxAmount,
    };
  }

  factory ProductDetail.fromMap(Map<String, dynamic> map) {
    return ProductDetail(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productDescription: map['productDescription'],
      productCategory: map['productCategory'],
      sku: map['sku'],
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      unitType: map['unitType'],
      discount: (map['discount'] as num?)?.toDouble(),
      taxAmount: (map['taxAmount'] as num?)?.toDouble(),
    );
  }
}

class CreditTransaction {
  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final DateTime transactionDate;
  final String type; // 'credit_sale', 'payment', 'adjustment'
  final double amount;
  final double previousBalance;
  final double newBalance;
  final String? orderId;
  final String? invoiceNumber;
  final String? notes;
  final String? paymentMethod;
  final DateTime? dueDate;
  final DateTime? createdDate;
  final String? createdBy;
  final List<ProductDetail>? productDetails; // Add this line


  CreditTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.transactionDate,
    required this.type,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    this.orderId,
    this.invoiceNumber,
    this.notes,
    this.paymentMethod,
    this.dueDate,
    this.createdDate,
    this.createdBy,
    this.productDetails, // Add this line

  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'transactionDate': transactionDate.toIso8601String(),
      'type': type,
      'amount': amount,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'orderId': orderId,
      'invoiceNumber': invoiceNumber,
      'notes': notes,
      'paymentMethod': paymentMethod,
      'dueDate': dueDate?.toIso8601String(),
      'createdDate': createdDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'createdBy': createdBy,
      'productDetails': productDetails?.map((detail) => detail.toMap()).toList(), // Add this line


    };
  }

  factory CreditTransaction.fromMap(Map<String, dynamic> map) {
    return CreditTransaction(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      transactionDate: DateTime.parse(map['transactionDate']),
      type: map['type'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      previousBalance: (map['previousBalance'] as num?)?.toDouble() ?? 0.0,
      newBalance: (map['newBalance'] as num?)?.toDouble() ?? 0.0,
      orderId: map['orderId'],
      invoiceNumber: map['invoiceNumber'],
      notes: map['notes'],
      paymentMethod: map['paymentMethod'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      createdDate: map['createdDate'] != null ? DateTime.parse(map['createdDate']) : null,
      createdBy: map['createdBy'],
      productDetails: map['productDetails'] != null ?
      (map['productDetails'] as List).map((detail) => ProductDetail.fromMap(detail)).toList() : null, // Add this line
    );
  }

  bool get isCredit => type == 'credit_sale';
  bool get isPayment => type == 'payment';
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now());
  int get daysOverdue => dueDate != null && isOverdue
      ? DateTime.now().difference(dueDate!).inDays
      : 0;
  bool get hasProductDetails => productDetails != null && productDetails!.isNotEmpty;

}

class CreditSummary {
  final String customerId;
  final String customerName;
  final double currentBalance;
  final double creditLimit;
  final double totalCreditGiven;
  final double totalCreditPaid;
  final int totalTransactions;
  final DateTime? lastTransactionDate;
  final DateTime? lastPaymentDate;
  final int overdueCount;
  final double overdueAmount;

  CreditSummary({
    required this.customerId,
    required this.customerName,
    required this.currentBalance,
    required this.creditLimit,
    required this.totalCreditGiven,
    required this.totalCreditPaid,
    required this.totalTransactions,
    this.lastTransactionDate,
    this.lastPaymentDate,
    this.overdueCount = 0,
    this.overdueAmount = 0.0,
  });

  double get availableCredit => creditLimit - currentBalance;
  double get utilizationRate => creditLimit > 0 ? (currentBalance / creditLimit) * 100 : 0;
  bool get isOverLimit => currentBalance > creditLimit;
}