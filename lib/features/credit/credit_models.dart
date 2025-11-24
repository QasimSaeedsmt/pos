// New file: credit_models.dart
import 'package:intl/intl.dart';

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
    );
  }

  bool get isCredit => type == 'credit_sale';
  bool get isPayment => type == 'payment';
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now());
  int get daysOverdue => dueDate != null && isOverdue
      ? DateTime.now().difference(dueDate!).inDays
      : 0;
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