// credit_models.dart



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

class CreditSaleData {
  final bool isCreditSale;
  final double creditAmount;
  final double paidAmount;
  final DateTime? dueDate;
  final String notes;
  final double previousBalance;
  final double newBalance;
  final String? creditTerms;

  CreditSaleData({
    required this.isCreditSale,
    this.creditAmount = 0.0,
    this.paidAmount = 0.0,
    this.dueDate,
    this.notes = '',
    this.previousBalance = 0.0,
    this.newBalance = 0.0,
    this.creditTerms,
  });

  Map<String, dynamic> toMap() {
    return {
      'isCreditSale': isCreditSale,
      'creditAmount': creditAmount,
      'paidAmount': paidAmount,
      'dueDate': dueDate?.toIso8601String(),
      'notes': notes,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'creditTerms': creditTerms,
    };
  }

  factory CreditSaleData.fromMap(Map<String, dynamic> map) {
    return CreditSaleData(
      isCreditSale: map['isCreditSale'] ?? false,
      creditAmount: (map['creditAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      notes: map['notes'] ?? '',
      previousBalance: (map['previousBalance'] as num?)?.toDouble() ?? 0.0,
      newBalance: (map['newBalance'] as num?)?.toDouble() ?? 0.0,
      creditTerms: map['creditTerms'],
    );
  }
}