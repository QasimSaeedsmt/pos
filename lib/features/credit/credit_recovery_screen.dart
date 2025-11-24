// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// import '../../constants.dart';
// import 'credit_models.dart';
// import 'credit_service.dart';
//
// class SimpleCreditRecoveryScreen extends StatefulWidget {
//   final CreditService creditService;
//
//   const SimpleCreditRecoveryScreen({super.key, required this.creditService});
//
//   @override
//   _SimpleCreditRecoveryScreenState createState() => _SimpleCreditRecoveryScreenState();
// }
//
// class _SimpleCreditRecoveryScreenState extends State<SimpleCreditRecoveryScreen> {
//   List<CreditTransaction> _overdueTransactions = [];
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadOverdue();
//   }
//
//   Future<void> _loadOverdue() async {
//     setState(() => _isLoading = true);
//     try {
//       final transactions = await widget.creditService.getOverdueTransactions();
//       setState(() => _overdueTransactions = transactions);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load overdue: $e')));
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Overdue Payments')),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : _overdueTransactions.isEmpty
//           ? Center(child: Text('No overdue payments'))
//           : ListView.builder(
//         itemCount: _overdueTransactions.length,
//         itemBuilder: (context, index) {
//           final transaction = _overdueTransactions[index];
//           return _buildOverdueItem(transaction);
//         },
//       ),
//     );
//   }
//
//   Widget _buildOverdueItem(CreditTransaction transaction) {
//     return Card(
//       margin: EdgeInsets.all(8),
//       child: ListTile(
//         leading: Icon(Icons.warning, color: Colors.orange),
//         title: Text(transaction.customerName),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Due: ${DateFormat('MMM dd, yyyy').format(transaction.dueDate!)}'),
//             Text('Overdue: ${transaction.daysOverdue} days', style: TextStyle(color: Colors.red)),
//           ],
//         ),
//         trailing: Text('${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}'),
//         onTap: () => _contactCustomer(transaction),
//       ),
//     );
//   }
//
//   void _contactCustomer(CreditTransaction transaction) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => Container(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Contact ${transaction.customerName}',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             SizedBox(height: 16),
//             ListTile(
//               leading: Icon(Icons.phone),
//               title: Text('Call Customer'),
//               onTap: () {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling...')));
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.payment),
//               title: Text('Record Payment'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _recordPaymentForTransaction(transaction);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _recordPaymentForTransaction(CreditTransaction transaction) {
//     // Simple payment recording for this transaction
//     // You can implement this based on your needs
//   }
// }