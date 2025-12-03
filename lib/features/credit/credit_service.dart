import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import 'credit_models.dart';

class CreditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }

  CollectionReference get _creditTransactionsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('credit_transactions');

  CollectionReference get _customersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customers');

  CollectionReference get _customerContactsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customer_contacts');

  // Record a credit transaction
  Future<void> recordCreditTransaction(CreditTransaction transaction) async {
    try {
      await _creditTransactionsRef.doc(transaction.id).set(transaction.toMap());
      debugPrint('✅ Credit transaction recorded: ${transaction.id}');
    } catch (e) {
      debugPrint('❌ Error recording credit transaction: $e');
      throw Exception('Failed to record credit transaction: $e');
    }
  }

  // Get customer transactions
  Future<List<CreditTransaction>> getCustomerTransactions(String customerId) async {
    try {
      final snapshot = await _creditTransactionsRef
          .where('customerId', isEqualTo: customerId)
          .orderBy('transactionDate', descending: true)
          .get();

      final transactions = snapshot.docs.map((doc) {
        return CreditTransaction.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();

      debugPrint('✅ Retrieved ${transactions.length} transactions for customer: $customerId');
      return transactions;
    } catch (e) {
      debugPrint('❌ Error getting customer transactions: $e');
      throw Exception('Failed to get customer transactions: $e');
    }
  }

  // Get all transactions
  Future<List<CreditTransaction>> getAllTransactions() async {
    try {
      final snapshot = await _creditTransactionsRef
          .orderBy('transactionDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return CreditTransaction.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting all transactions: $e');
      return [];
    }
  }

  // Get all customers with credit balances
  Future<List<CreditSummary>> getAllCreditCustomers() async {
    try {
      final snapshot = await _customersRef
          .where('currentBalance', isGreaterThan: 0)
          .get();

      final List<CreditSummary> summaries = [];

      for (final doc in snapshot.docs) {
        final customerData = doc.data() as Map<String, dynamic>;
        final customerName = '${customerData['firstName']} ${customerData['lastName']}';

        // Get transactions for this customer
        final transactions = await getCustomerTransactions(doc.id);

        // Calculate overdue amounts
        double overdueAmount = 0.0;
        int overdueCount = 0;

        for (final transaction in transactions) {
          if (transaction.isCredit && transaction.isOverdue) {
            overdueAmount += transaction.amount;
            overdueCount++;
          }
        }

        final summary = CreditSummary(
          customerId: doc.id,
          customerName: customerName,
          currentBalance: (customerData['currentBalance'] as num?)?.toDouble() ?? 0.0,
          creditLimit: (customerData['creditLimit'] as num?)?.toDouble() ?? 0.0,
          totalCreditGiven: (customerData['totalCreditGiven'] as num?)?.toDouble() ?? 0.0,
          totalCreditPaid: (customerData['totalCreditPaid'] as num?)?.toDouble() ?? 0.0,
          totalTransactions: transactions.length,
          lastTransactionDate: customerData['lastCreditDate'] != null
              ? DateTime.parse(customerData['lastCreditDate'])
              : null,
          lastPaymentDate: customerData['lastPaymentDate'] != null
              ? DateTime.parse(customerData['lastPaymentDate'])
              : null,
          overdueCount: overdueCount,
          overdueAmount: overdueAmount,
        );

        summaries.add(summary);
      }

      debugPrint('✅ Generated credit summaries for ${summaries.length} customers');
      return summaries;
    } catch (e) {
      debugPrint('❌ Error getting credit customers: $e');
      throw Exception('Failed to get credit customers: $e');
    }
  }

  // Record a payment
  Future<void> recordPayment({
    required String customerId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      // Get customer current balance
      final customerDoc = await _customersRef.doc(customerId).get();
      if (!customerDoc.exists) {
        throw Exception('Customer not found');
      }

      final customerData = customerDoc.data() as Map<String, dynamic>;
      final currentBalance = (customerData['currentBalance'] as num?)?.toDouble() ?? 0.0;

      if (amount > currentBalance) {
        throw Exception('Payment amount cannot exceed current balance');
      }

      final newBalance = currentBalance - amount;

      final transaction = CreditTransaction(
        id: 'payment_${DateTime.now().millisecondsSinceEpoch}',
        customerId: customerId,
        customerName: '${customerData['firstName']} ${customerData['lastName']}',
        customerEmail: customerData['email'] ?? '',
        transactionDate: DateTime.now(),
        type: 'payment',
        amount: amount,
        previousBalance: currentBalance,
        newBalance: newBalance,
        paymentMethod: paymentMethod,
        notes: notes,
        createdDate: DateTime.now(),
      );

      await recordCreditTransaction(transaction);

      // Update customer balance
      await _customersRef.doc(customerId).update({
        'currentBalance': newBalance,
        'totalCreditPaid': ((customerData['totalCreditPaid'] as num?)?.toDouble() ?? 0.0) + amount,
        'lastPaymentDate': DateTime.now().toIso8601String(),
        'dateModified': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Payment recorded for customer: $customerId, amount: $amount');
    } catch (e) {
      debugPrint('❌ Error recording payment: $e');
      throw Exception('Failed to record payment: $e');
    }
  }

  // Get credit analytics data
  Future<Map<String, dynamic>> getCreditAnalytics() async {
    try {
      final creditCustomers = await getAllCreditCustomers();
      final allTransactions = await getAllTransactions();

      final totalOutstanding = creditCustomers.fold(0.0, (sum, customer) => sum + customer.currentBalance);
      final totalOverdue = creditCustomers.fold(0.0, (sum, customer) => sum + customer.overdueAmount);
      final customersOverLimit = creditCustomers.where((c) => c.isOverLimit).length;
      final customersWithOverdue = creditCustomers.where((c) => c.overdueCount > 0).length;

      // Calculate payment method analytics
      final paymentAnalytics = await getPaymentMethodAnalytics();

      // Calculate monthly trends
      final monthlyTrends = await getMonthlyTrends();

      final analytics = {
        'totalOutstanding': totalOutstanding,
        'totalOverdue': totalOverdue,
        'totalCreditCustomers': creditCustomers.length,
        'customersOverLimit': customersOverLimit,
        'customersWithOverdue': customersWithOverdue,
        'averageBalance': creditCustomers.isNotEmpty ? totalOutstanding / creditCustomers.length : 0,
        'recoveryRate': totalOutstanding > 0 ? ((totalOutstanding - totalOverdue) / totalOutstanding) * 100 : 100,
        'totalTransactions': allTransactions.length,
        'paymentMethodAnalytics': paymentAnalytics,
        'monthlyTrends': monthlyTrends,
      };

      debugPrint('✅ Generated comprehensive credit analytics');
      return analytics;
    } catch (e) {
      debugPrint('❌ Error getting credit analytics: $e');
      throw Exception('Failed to get credit analytics: $e');
    }
  }

  // Get payment method analytics
  Future<Map<String, dynamic>> getPaymentMethodAnalytics() async {
    try {
      final transactions = await getAllTransactions();
      final Map<String, dynamic> analytics = {};

      for (final transaction in transactions) {
        if (transaction.isPayment && transaction.paymentMethod != null) {
          final method = transaction.paymentMethod!;
          if (!analytics.containsKey(method)) {
            analytics[method] = {'count': 0, 'amount': 0.0};
          }
          analytics[method]['count']++;
          analytics[method]['amount'] += transaction.amount;
        }
      }

      return analytics;
    } catch (e) {
      debugPrint('❌ Error getting payment method analytics: $e');
      return {};
    }
  }

  // Get monthly trends
  Future<Map<String, dynamic>> getMonthlyTrends() async {
    try {
      final transactions = await getAllTransactions();
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      final currentMonthTransactions = transactions.where((t) =>
      t.transactionDate.month == now.month && t.transactionDate.year == now.year
      );

      final lastMonthTransactions = transactions.where((t) =>
      t.transactionDate.month == lastMonth.month && t.transactionDate.year == lastMonth.year
      );

      final currentMonthRevenue = currentMonthTransactions
          .where((t) => t.isPayment)
          .fold(0.0, (sum, t) => sum + t.amount);

      final lastMonthRevenue = lastMonthTransactions
          .where((t) => t.isPayment)
          .fold(0.0, (sum, t) => sum + t.amount);

      final revenueGrowth = lastMonthRevenue > 0 ?
      ((currentMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100 : 0;

      return {
        'currentMonthRevenue': currentMonthRevenue,
        'lastMonthRevenue': lastMonthRevenue,
        'revenueGrowth': revenueGrowth,
        'currentMonthTransactions': currentMonthTransactions.length,
        'lastMonthTransactions': lastMonthTransactions.length,
      };
    } catch (e) {
      debugPrint('❌ Error getting monthly trends: $e');
      return {};
    }
  }

  // Get overdue transactions
  Future<List<CreditTransaction>> getOverdueTransactions() async {
    try {
      final allCustomers = await getAllCreditCustomers();
      final List<CreditTransaction> overdueTransactions = [];

      for (final customer in allCustomers) {
        final transactions = await getCustomerTransactions(customer.customerId);
        final overdue = transactions.where((t) => t.isOverdue).toList();
        overdueTransactions.addAll(overdue);
      }

      // Sort by days overdue (descending)
      overdueTransactions.sort((a, b) {
        final aDays = a.daysOverdue;
        final bDays = b.daysOverdue;
        return bDays.compareTo(aDays);
      });

      debugPrint('✅ Found ${overdueTransactions.length} overdue transactions');
      return overdueTransactions;
    } catch (e) {
      debugPrint('❌ Error getting overdue transactions: $e');
      throw Exception('Failed to get overdue transactions: $e');
    }
  }

  // Record customer contact
  Future<void> recordCustomerContact({
    required String customerId,
    required String transactionId,
    required String contactMethod,
    required String notes,
    required String contactedBy,
  }) async {
    try {
      final contactId = 'contact_${DateTime.now().millisecondsSinceEpoch}';

      // Get customer name for the contact record
      final customerDoc = await _customersRef.doc(customerId).get();
      final customerData = customerDoc.data() as Map<String, dynamic>;
      final customerName = '${customerData['firstName']} ${customerData['lastName']}';

      await _customerContactsRef.doc(contactId).set({
        'id': contactId,
        'customerId': customerId,
        'customerName': customerName,
        'transactionId': transactionId,
        'contactMethod': contactMethod,
        'notes': notes,
        'contactDate': DateTime.now().toIso8601String(),
        'contactedBy': contactedBy,
      });

      debugPrint('✅ Customer contact recorded: $contactId');
    } catch (e) {
      debugPrint('❌ Error recording customer contact: $e');
      throw Exception('Failed to record customer contact: $e');
    }
  }


}
// Get recent customer contacts
// Future<List<CustomerContact>> getRecentCustomerContacts() async {
//   try {
//     final snapshot = await _customerContactsRef
//         .orderBy('contactDate', descending: true)
//         .limit(50)
//         .get();
//
//     return snapshot.docs.map((doc) {
//       final data = doc.data() as Map<String, dynamic>;
//       return CustomerContact(
//         id: data['id'] ?? '',
//         customerId: data['customerId'] ?? '',
//         customerName: data['customerName'] ?? '',
//         transactionId: data['transactionId'] ?? '',
//         contactMethod: data['contactMethod'] ?? '',
//         notes: data['notes'] ?? '',
//         contactDate: DateTime.parse(data['contactDate']),
//         contactedBy: data['contactedBy'] ?? '',
//       );
//     }).toList();
//   } catch (e) {
//     debugPrint('❌ Error getting customer contacts: $e');
//     return [];
//   }
// }
//
// // Get customer-specific contacts
// Future<List<CustomerContact>> getCustomerContacts(String customerId) async {
//   try {
//     final snapshot = await _customerContactsRef
//         .where('customerId', isEqualTo: customerId)
//         .orderBy('contactDate', descending: true)
//         .get();
//
//     return snapshot.docs.map((doc) {
//       final data = doc.data() as Map<String, dynamic>;
//       return CustomerContact(
//         id: data['id'] ?? '',
//         customerId: data['customerId'] ?? '',
//         customerName: data['customerName'] ?? '',
//         transactionId: data['transactionId'] ?? '',
//         contactMethod: data['contactMethod'] ?? '',
//         notes: data['notes'] ?? '',
//         contactDate: DateTime.parse(data['contactDate']),
//         contactedBy: data['contactedBy'] ?? '',
//       );
//     }).toList();
//   } catch (e) {
//     debugPrint('❌ Error getting customer contacts: $e');
//     return [];
//   }
// }

// Get recovery performance metrics
// Future<Map<String, dynamic>> getRecoveryPerformance() async {
//   try {
//     final contacts = await getRecentCustomerContacts();
//     final overdueTransactions = await getOverdueTransactions();
//
//     final contactedTransactions = contacts.map((c) => c.transactionId).toSet();
//     final contactedOverdue = overdueTransactions.where((t) =>
//         contactedTransactions.contains(t.id)
//     ).length;
//
//     final recoveryRate = overdueTransactions.isNotEmpty ?
//     (contactedOverdue / overdueTransactions.length) * 100 : 0;
//
//     return {
//       'totalOverdue': overdueTransactions.length,
//       'contactedCount': contactedOverdue,
//       'recoveryRate': recoveryRate,
//       'averageResponseTime': 24, // hours - would need more data
//       'successRate': 65.0, // placeholder - would track actual payments after contact
//     };
//   } catch (e) {
//     debugPrint('❌ Error getting recovery performance: $e');
//     return {};
//   }
// }