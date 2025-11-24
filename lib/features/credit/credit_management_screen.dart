// import 'package:flutter/material.dart';
//
// import '../../constants.dart';
// import '../main_navigation/main_navigation_base.dart';
// import 'credit_analytics_screen.dart';
// import 'credit_models.dart';
// import 'credit_service.dart';
// import 'customer_credit_detail_screen.dart';
// class CreditManagementScreen extends StatefulWidget {
//   final EnhancedPOSService posService;
//
//   const CreditManagementScreen({super.key, required this.posService});
//
//   @override
//   _CreditManagementScreenState createState() => _CreditManagementScreenState();
// }
//
// class _CreditManagementScreenState extends State<CreditManagementScreen> {
//   final CreditService _creditService = CreditService();
//   List<CreditSummary> _customers = [];
//   bool _isLoading = true;
//   String _debugInfo = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCustomers();
//   }
//
//   Future<void> _loadCustomers() async {
//     setState(() {
//       _isLoading = true;
//       _debugInfo = 'Loading...';
//     });
//
//     try {
//       print('🔄 Loading credit customers...');
//       final customers = await _creditService.getAllCreditCustomers();
//       print('✅ Loaded ${customers.length} customers');
//
//       // Debug: Print each customer's data
//       for (var customer in customers) {
//         print('📋 Customer: ${customer.customerName}, Balance: ${customer.currentBalance}, ID: ${customer.customerId}');
//       }
//
//       setState(() {
//         _customers = customers;
//         _debugInfo = 'Found ${customers.length} customers';
//       });
//
//     } catch (e) {
//       print('❌ Error loading customers: $e');
//       setState(() {
//         _debugInfo = 'Error: $e';
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to load customers: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Credit Management'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadCustomers,
//           ),
//           IconButton(
//             icon: Icon(Icons.bug_report),
//             onPressed: _showDebugInfo,
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? Center(child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(),
//           SizedBox(height: 16),
//           Text('Loading credit customers...'),
//         ],
//       ))
//           : _customers.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
//             SizedBox(height: 16),
//             Text('No credit customers found'),
//             SizedBox(height: 8),
//             Text(
//               _debugInfo,
//               style: TextStyle(color: Colors.grey, fontSize: 12),
//             ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _loadCustomers,
//               child: Text('Retry'),
//             ),
//           ],
//         ),
//       )
//           : Column(
//         children: [
//           // Debug info
//           if (_debugInfo.isNotEmpty)
//             Container(
//               padding: EdgeInsets.all(8),
//               color: Colors.grey[100],
//               child: Row(
//                 children: [
//                   Icon(Icons.info, size: 16, color: Colors.blue),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       _debugInfo,
//                       style: TextStyle(fontSize: 12, color: Colors.blue),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//           // Customers list
//           Expanded(
//             child: ListView.builder(
//               itemCount: _customers.length,
//               itemBuilder: (context, index) {
//                 final customer = _customers[index];
//                 return _buildCustomerCard(customer);
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => CreditAnalyticsScreen(creditService: _creditService),
//           ),
//         ),
//         child: Icon(Icons.analytics),
//       ),
//     );
//   }
//
//   Widget _buildCustomerCard(CreditSummary customer) {
//     return Card(
//       margin: EdgeInsets.all(8),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: _getStatusColor(customer).withOpacity(0.1),
//           child: Icon(Icons.person, color: _getStatusColor(customer)),
//         ),
//         title: Text(
//           customer.customerName,
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Balance: ${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}',
//               style: TextStyle(
//                 color: customer.currentBalance > 0 ? Colors.orange : Colors.green,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             if (customer.creditLimit > 0)
//               Text(
//                 'Limit: ${Constants.CURRENCY_NAME}${customer.creditLimit.toStringAsFixed(2)}',
//                 style: TextStyle(fontSize: 12),
//               ),
//             if (customer.overdueCount > 0)
//               Container(
//                 margin: EdgeInsets.only(top: 4),
//                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: Colors.red[50],
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Text(
//                   '${customer.overdueCount} overdue • ${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}',
//                   style: TextStyle(
//                     fontSize: 10,
//                     color: Colors.red[700],
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             IconButton(
//               icon: Icon(Icons.payment, color: Colors.green),
//               onPressed: () => _recordPayment(customer),
//               tooltip: 'Record Payment',
//             ),
//             IconButton(
//               icon: Icon(Icons.visibility, color: Colors.blue),
//               onPressed: () => _showCustomerDetails(customer),
//               tooltip: 'View Details',
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Color _getStatusColor(CreditSummary customer) {
//     if (customer.isOverLimit) return Colors.red;
//     if (customer.overdueCount > 0) return Colors.orange;
//     if (customer.currentBalance > 0) return Colors.blue;
//     return Colors.green;
//   }
//
//   void _showDebugInfo() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Debug Information'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Customers loaded: ${_customers.length}'),
//               SizedBox(height: 16),
//               Text('Debug info: $_debugInfo'),
//               SizedBox(height: 16),
//               Text('Service: ${_creditService.runtimeType}'),
//               SizedBox(height: 16),
//               if (_customers.isNotEmpty) ...[
//                 Text('Sample customer data:'),
//                 ..._customers.take(3).map((customer) => Text(
//                   '- ${customer.customerName}: ${Constants.CURRENCY_NAME}${customer.currentBalance}',
//                   style: TextStyle(fontSize: 12),
//                 )),
//               ],
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//           TextButton(
//             onPressed: () {
//               _loadCustomers();
//               Navigator.pop(context);
//             },
//             child: Text('Reload'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _recordPayment(CreditSummary customer) {
//     final amountController = TextEditingController(
//       text: customer.currentBalance.toStringAsFixed(2),
//     );
//     final notesController = TextEditingController();
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Record Payment - ${customer.customerName}'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.blue[50],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.info, color: Colors.blue, size: 20),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Current Balance: ${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}',
//                       style: TextStyle(fontWeight: FontWeight.w600),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: amountController,
//               decoration: InputDecoration(
//                 labelText: 'Payment Amount',
//                 prefixText: Constants.CURRENCY_NAME,
//                 border: OutlineInputBorder(),
//               ),
//               keyboardType: TextInputType.numberWithOptions(decimal: true),
//             ),
//             SizedBox(height: 12),
//             TextField(
//               controller: notesController,
//               decoration: InputDecoration(
//                 labelText: 'Notes (optional)',
//                 border: OutlineInputBorder(),
//               ),
//               maxLines: 2,
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
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Please enter a valid amount')),
//                 );
//                 return;
//               }
//
//               if (amount > customer.currentBalance) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Payment amount cannot exceed current balance')),
//                 );
//                 return;
//               }
//
//               try {
//                 await _creditService.recordPayment(
//                   customerId: customer.customerId,
//                   amount: amount,
//                   paymentMethod: 'cash',
//                   notes: notesController.text.isNotEmpty ? notesController.text : null,
//                 );
//
//                 Navigator.pop(context);
//                 _loadCustomers(); // Refresh list
//
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Payment of ${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)} recorded successfully'),
//                     backgroundColor: Colors.green,
//                   ),
//                 );
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('Failed to record payment: $e')),
//                 );
//               }
//             },
//             child: Text('Record Payment'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showCustomerDetails(CreditSummary customer) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => SimpleCustomerCreditScreen(
//           customerSummary: customer,
//           creditService: _creditService,
//
//         ),
//       ),
//     );
//   }
// }