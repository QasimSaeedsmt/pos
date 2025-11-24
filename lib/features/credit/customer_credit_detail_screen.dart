// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:mpcm/constants.dart';
//
// import 'credit_models.dart';
// import 'credit_service.dart';
//
// class SimpleCustomerCreditScreen extends StatefulWidget {
//   final CreditSummary customerSummary;
//   final CreditService creditService;
//
//   const SimpleCustomerCreditScreen({
//     super.key,
//     required this.customerSummary,
//     required this.creditService,
//   });
//
//   @override
//   _SimpleCustomerCreditScreenState createState() => _SimpleCustomerCreditScreenState();
// }
//
// class _SimpleCustomerCreditScreenState extends State<SimpleCustomerCreditScreen> {
//   List<CreditTransaction> _transactions = [];
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadTransactions();
//   }
//
//   Future<void> _loadTransactions() async {
//     setState(() => _isLoading = true);
//     try {
//       final transactions = await widget.creditService.getCustomerTransactions(widget.customerSummary.customerId);
//       setState(() => _transactions = transactions);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load transactions: $e')));
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.customerSummary.customerName)),
//       body: Column(
//         children: [
//           // Customer summary card
//           Card(
//             margin: EdgeInsets.all(16),
//             child: Padding(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   _buildSummaryItem('Current Balance', widget.customerSummary.currentBalance),
//                   _buildSummaryItem('Credit Limit', widget.customerSummary.creditLimit),
//                   _buildSummaryItem('Available Credit', widget.customerSummary.availableCredit),
//                   if (widget.customerSummary.overdueCount > 0)
//                     _buildSummaryItem('Overdue', widget.customerSummary.overdueAmount, isWarning: true),
//                 ],
//               ),
//             ),
//           ),
//
//           // Transactions
//           Expanded(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : _transactions.isEmpty
//                 ? Center(child: Text('No transactions'))
//                 : ListView.builder(
//               itemCount: _transactions.length,
//               itemBuilder: (context, index) {
//                 final transaction = _transactions[index];
//                 return _buildTransactionItem(transaction);
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _recordPayment,
//         child: Icon(Icons.payment),
//       ),
//     );
//   }
//
//   Widget _buildSummaryItem(String label, double value, {bool isWarning = false}) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label),
//           Text(
//             '${Constants.CURRENCY_NAME}${value.toStringAsFixed(2)}',
//             style: TextStyle(
//               color: isWarning ? Colors.red : Colors.black,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTransactionItem(CreditTransaction transaction) {
//     return Card(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       child: ListTile(
//         leading: Icon(
//           transaction.isPayment ? Icons.payment : Icons.shopping_cart,
//           color: transaction.isPayment ? Colors.green : Colors.orange,
//         ),
//         title: Text(transaction.isPayment ? 'Payment' : 'Credit Sale'),
//         subtitle: Text(DateFormat('MMM dd, yyyy').format(transaction.transactionDate)),
//         trailing: Text(
//           '${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: transaction.isPayment ? Colors.green : Colors.orange,
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _recordPayment() {
//     final amountController = TextEditingController();
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Record Payment'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Balance: ${Constants.CURRENCY_NAME}${widget.customerSummary.currentBalance.toStringAsFixed(2)}'),
//             SizedBox(height: 16),
//             TextField(
//               controller: amountController,
//               decoration: InputDecoration(
//                 labelText: 'Amount',
//                 prefixText: Constants.CURRENCY_NAME,
//               ),
//               keyboardType: TextInputType.number,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               final amount = double.tryParse(amountController.text);
//               if (amount == null || amount <= 0) {
//                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter valid amount')));
//                 return;
//               }
//
//               try {
//                 await widget.creditService.recordPayment(
//                   customerId: widget.customerSummary.customerId,
//                   amount: amount,
//                   paymentMethod: 'cash',
//                   notes: 'Payment recorded',
//                 );
//                 Navigator.pop(context);
//                 _loadTransactions(); // Refresh
//                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment recorded')));
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
//               }
//             },
//             child: Text('Record'),
//           ),
//         ],
//       ),
//     );
//   }
// }