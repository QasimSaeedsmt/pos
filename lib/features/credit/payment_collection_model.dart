// // New file: payment_collection_modal.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// import '../../constants.dart';
// import 'credit_models.dart';
// import 'credit_service.dart';
//
// class PaymentCollectionModal extends StatefulWidget {
//   final CreditSummary customerSummary;
//   final CreditService creditService;
//   final VoidCallback onPaymentRecorded;
//
//   const PaymentCollectionModal({
//     super.key,
//     required this.customerSummary,
//     required this.creditService,
//     required this.onPaymentRecorded,
//   });
//
//   @override
//   _PaymentCollectionModalState createState() => _PaymentCollectionModalState();
// }
//
// class _PaymentCollectionModalState extends State<PaymentCollectionModal> {
//   final TextEditingController _amountController = TextEditingController();
//   final TextEditingController _notesController = TextEditingController();
//   final List<String> _paymentMethods = [
//     'cash',
//     'bank_transfer',
//     'easypaisa',
//     'jazzcash',
//     'cheque',
//     'other'
//   ];
//   String _selectedPaymentMethod = 'cash';
//   bool _isProcessing = false;
//
//   @override
//   void initState() {
//     super.initState();
//     // Pre-fill with current balance
//     _amountController.text = widget.customerSummary.currentBalance.toStringAsFixed(2);
//   }
//
//   double get _enteredAmount => double.tryParse(_amountController.text) ?? 0.0;
//   bool get _isValidAmount => _enteredAmount > 0 && _enteredAmount <= widget.customerSummary.currentBalance;
//
//   void _recordPayment() async {
//     if (!_isValidAmount) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please enter a valid payment amount')),
//       );
//       return;
//     }
//
//     setState(() => _isProcessing = true);
//
//     try {
//       await widget.creditService.recordPayment(
//         customerId: widget.customerSummary.customerId,
//         amount: _enteredAmount,
//         paymentMethod: _selectedPaymentMethod,
//         notes: _notesController.text.trim(),
//       );
//
//       widget.onPaymentRecorded();
//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to record payment: $e')),
//       );
//     } finally {
//       setState(() => _isProcessing = false);
//     }
//   }
//
//   String _getPaymentMethodName(String method) {
//     switch (method) {
//       case 'cash': return 'Cash';
//       case 'bank_transfer': return 'Bank Transfer';
//       case 'easypaisa': return 'Easypaisa';
//       case 'jazzcash': return 'JazzCash';
//       case 'cheque': return 'Cheque';
//       case 'other': return 'Other';
//       default: return method;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       insetPadding: EdgeInsets.all(20),
//       child: Container(
//         constraints: BoxConstraints(maxWidth: 500),
//         child: Padding(
//           padding: EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               _buildHeader(),
//               SizedBox(height: 24),
//
//               // Customer Info
//               _buildCustomerInfo(),
//               SizedBox(height: 20),
//
//               // Amount Input
//               _buildAmountInput(),
//               SizedBox(height: 20),
//
//               // Payment Method
//               _buildPaymentMethod(),
//               SizedBox(height: 20),
//
//               // Notes
//               _buildNotesInput(),
//               SizedBox(height: 24),
//
//               // Summary
//               _buildSummary(),
//               SizedBox(height: 24),
//
//               // Action Buttons
//               _buildActionButtons(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Row(
//       children: [
//         Icon(Icons.payment, size: 28, color: Colors.green),
//         SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Record Payment',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               Text(
//                 'Collect payment from ${widget.customerSummary.customerName}',
//                 style: TextStyle(color: Colors.grey[600]),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildCustomerInfo() {
//     return Card(
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Container(
//               width: 44,
//               height: 44,
//               decoration: BoxDecoration(
//                 color: Colors.green[100],
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(Icons.person, color: Colors.green),
//             ),
//             SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     widget.customerSummary.customerName,
//                     style: TextStyle(fontWeight: FontWeight.w500),
//                   ),
//                   SizedBox(height: 4),
//                   Text(
//                     'Current Balance: ${Constants.CURRENCY_NAME}${widget.customerSummary.currentBalance.toStringAsFixed(2)}',
//                     style: TextStyle(
//                       color: Colors.orange,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAmountInput() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Payment Amount',
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         SizedBox(height: 8),
//         TextField(
//           controller: _amountController,
//           decoration: InputDecoration(
//             labelText: 'Enter payment amount',
//             prefixText: Constants.CURRENCY_NAME,
//             border: OutlineInputBorder(),
//             suffixIcon: IconButton(
//               icon: Icon(Icons.attach_money),
//               onPressed: () {
//                 _amountController.text = widget.customerSummary.currentBalance.toStringAsFixed(2);
//               },
//             ),
//           ),
//           keyboardType: TextInputType.numberWithOptions(decimal: true),
//           onChanged: (value) => setState(() {}),
//         ),
//         SizedBox(height: 8),
//         if (!_isValidAmount && _enteredAmount > 0)
//           Text(
//             'Amount cannot exceed current balance',
//             style: TextStyle(color: Colors.red, fontSize: 12),
//           ),
//       ],
//     );
//   }
//
//   Widget _buildPaymentMethod() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Payment Method',
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: _paymentMethods.map((method) {
//             final isSelected = _selectedPaymentMethod == method;
//             return ChoiceChip(
//               label: Text(_getPaymentMethodName(method)),
//               selected: isSelected,
//               onSelected: (selected) => setState(() => _selectedPaymentMethod = method),
//               selectedColor: Colors.green[100],
//               labelStyle: TextStyle(
//                 color: isSelected ? Colors.green[800] : Colors.grey[800],
//               ),
//             );
//           }).toList(),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildNotesInput() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Notes (Optional)',
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         SizedBox(height: 8),
//         TextField(
//           controller: _notesController,
//           decoration: InputDecoration(
//             labelText: 'e.g., "Partial payment", "Received in cash"',
//             border: OutlineInputBorder(),
//           ),
//           maxLines: 3,
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSummary() {
//     final newBalance = widget.customerSummary.currentBalance - _enteredAmount;
//
//     return Card(
//       color: Colors.green[50],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             _buildSummaryRow('Current Balance', widget.customerSummary.currentBalance),
//             _buildSummaryRow('Payment Amount', _enteredAmount, isPayment: true),
//             Divider(),
//             _buildSummaryRow('New Balance', newBalance, isTotal: true),
//             if (newBalance == 0) ...[
//               SizedBox(height: 8),
//               Container(
//                 padding: EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.green[100],
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.check_circle, size: 16, color: Colors.green),
//                     SizedBox(width: 8),
//                     Text(
//                       'Balance will be fully cleared',
//                       style: TextStyle(
//                         color: Colors.green[800],
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSummaryRow(String label, double amount, {
//     bool isPayment = false,
//     bool isTotal = false,
//   }) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
//               color: isPayment ? Colors.green :
//               isTotal ? Colors.green[800] : Colors.black,
//             ),
//           ),
//           Text(
//             '${isPayment ? '-' : ''}${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
//             style: TextStyle(
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
//               color: isPayment ? Colors.green :
//               isTotal ? Colors.green[800] : Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildActionButtons() {
//     return Row(
//       children: [
//         Expanded(
//           child: OutlinedButton(
//             onPressed: _isProcessing ? null : () => Navigator.pop(context),
//             style: OutlinedButton.styleFrom(
//               padding: EdgeInsets.symmetric(vertical: 16),
//             ),
//             child: Text('CANCEL'),
//           ),
//         ),
//         SizedBox(width: 16),
//         Expanded(
//           child: ElevatedButton(
//             onPressed: _isProcessing || !_isValidAmount ? null : _recordPayment,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green,
//               padding: EdgeInsets.symmetric(vertical: 16),
//             ),
//             child: _isProcessing
//                 ? SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: Colors.white,
//               ),
//             )
//                 : Text(
//               'RECORD PAYMENT',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   @override
//   void dispose() {
//     _amountController.dispose();
//     _notesController.dispose();
//     super.dispose();
//   }
// }