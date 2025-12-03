import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final int orderCount;
  final double totalSpent;
  final String? notes;
  final Map<String, dynamic> metaData;

  // Enhanced Credit Fields
  final double creditLimit;
  final double currentBalance;
  final double totalCreditGiven;
  final double totalCreditPaid;
  final DateTime? lastCreditDate;
  final DateTime? lastPaymentDate;
  final Map<String, dynamic> creditTerms;
  final double overdueAmount;
  final int overdueCount;

  Customer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postcode,
    this.country,
    this.dateCreated,
    this.dateModified,
    this.orderCount = 0,
    this.totalSpent = 0.0,
    this.notes,
    this.metaData = const {},
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
    this.totalCreditGiven = 0.0,
    this.totalCreditPaid = 0.0,
    this.lastCreditDate,
    this.lastPaymentDate,
    this.creditTerms = const {},
    this.overdueAmount = 0.0,
    this.overdueCount = 0,
  });

  String get fullName => '$firstName $lastName';
  String get displayName =>
      company?.isNotEmpty == true ? '$fullName ($company)' : fullName;

  // Enhanced credit helper methods
  bool get hasCreditLimit => creditLimit > 0;
  bool get isOverLimit => currentBalance > creditLimit;
  double get availableCredit => creditLimit - currentBalance;
  double get creditUtilization => creditLimit > 0 ? (currentBalance / creditLimit) * 100 : 0;
  bool get hasOverdue => overdueAmount > 0;
  bool get canMakeCreditSale => hasCreditLimit ? !isOverLimit : true;

  factory Customer.fromFirestore(Map<String, dynamic> data, String id) {
    return Customer(
      id: id,
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      company: data['company']?.toString(),
      address1: data['address1']?.toString(),
      address2: data['address2']?.toString(),
      city: data['city']?.toString(),
      state: data['state']?.toString(),
      postcode: data['postcode']?.toString(),
      country: data['country']?.toString(),
      dateCreated: data['dateCreated'] is Timestamp
          ? (data['dateCreated'] as Timestamp).toDate()
          : data['dateCreated'] is String
          ? DateTime.tryParse(data['dateCreated'])
          : null,
      dateModified: data['dateModified'] is Timestamp
          ? (data['dateModified'] as Timestamp).toDate()
          : data['dateModified'] is String
          ? DateTime.tryParse(data['dateModified'])
          : null,
      orderCount: (data['orderCount'] as num?)?.toInt() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes']?.toString(),
      metaData: data['metaData'] is Map
          ? Map<String, dynamic>.from(data['metaData'])
          : {},
      creditLimit: (data['creditLimit'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (data['currentBalance'] as num?)?.toDouble() ?? 0.0,
      totalCreditGiven: (data['totalCreditGiven'] as num?)?.toDouble() ?? 0.0,
      totalCreditPaid: (data['totalCreditPaid'] as num?)?.toDouble() ?? 0.0,
      lastCreditDate: data['lastCreditDate'] is Timestamp
          ? (data['lastCreditDate'] as Timestamp).toDate()
          : data['lastCreditDate'] is String
          ? DateTime.tryParse(data['lastCreditDate'])
          : null,
      lastPaymentDate: data['lastPaymentDate'] is Timestamp
          ? (data['lastPaymentDate'] as Timestamp).toDate()
          : data['lastPaymentDate'] is String
          ? DateTime.tryParse(data['lastPaymentDate'])
          : null,
      creditTerms: data['creditTerms'] is Map
          ? Map<String, dynamic>.from(data['creditTerms'])
          : {},
      overdueAmount: (data['overdueAmount'] as num?)?.toDouble() ?? 0.0,
      overdueCount: (data['overdueCount'] as num?)?.toInt() ?? 0,
    );
  }

  // Enhanced copyWith method for credit operations
  Customer copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postcode,
    String? country,
    String? notes,
    double? creditLimit,
    double? currentBalance,
    double? totalCreditGiven,
    double? totalCreditPaid,
    DateTime? lastCreditDate,
    DateTime? lastPaymentDate,
    Map<String, dynamic>? creditTerms,
    double? overdueAmount,
    int? overdueCount,
  }) {
    return Customer(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      postcode: postcode ?? this.postcode,
      country: country ?? this.country,
      dateCreated: dateCreated,
      dateModified: DateTime.now(),
      orderCount: orderCount,
      totalSpent: totalSpent,
      notes: notes ?? this.notes,
      metaData: metaData,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      totalCreditGiven: totalCreditGiven ?? this.totalCreditGiven,
      totalCreditPaid: totalCreditPaid ?? this.totalCreditPaid,
      lastCreditDate: lastCreditDate ?? this.lastCreditDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      creditTerms: creditTerms ?? this.creditTerms,
      overdueAmount: overdueAmount ?? this.overdueAmount,
      overdueCount: overdueCount ?? this.overdueCount,
    );
  }

  // Specific credit copy method
  Customer copyWithCredit({
    double? creditLimit,
    double? currentBalance,
    double? totalCreditGiven,
    double? totalCreditPaid,
    DateTime? lastCreditDate,
    DateTime? lastPaymentDate,
    Map<String, dynamic>? creditTerms,
    double? overdueAmount,
    int? overdueCount,
  }) {
    return copyWith(
      creditLimit: creditLimit,
      currentBalance: currentBalance,
      totalCreditGiven: totalCreditGiven,
      totalCreditPaid: totalCreditPaid,
      lastCreditDate: lastCreditDate,
      lastPaymentDate: lastPaymentDate,
      creditTerms: creditTerms,
      overdueAmount: overdueAmount,
      overdueCount: overdueCount,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'company': company,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
      'dateCreated': dateCreated?.toIso8601String(),
      'dateModified': dateModified?.toIso8601String(),
      'orderCount': orderCount,
      'totalSpent': totalSpent,
      'notes': notes,
      'metaData': metaData,
      'searchKeywords': _generateSearchKeywords(),
      // Credit fields
      'creditLimit': creditLimit,
      'currentBalance': currentBalance,
      'totalCreditGiven': totalCreditGiven,
      'totalCreditPaid': totalCreditPaid,
      'lastCreditDate': lastCreditDate?.toIso8601String(),
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      'creditTerms': creditTerms,
      'overdueAmount': overdueAmount,
      'overdueCount': overdueCount,
    };
  }

  List<String> _generateSearchKeywords() {
    final keywords = <String>[];
    keywords.addAll(fullName.toLowerCase().split(' '));
    keywords.addAll(email.toLowerCase().split('@'));
    keywords.add(phone);
    if (company != null) {
      keywords.addAll(company!.toLowerCase().split(' '));
    }
    return keywords.where((k) => k.length > 1).toSet().toList();
  }
}
