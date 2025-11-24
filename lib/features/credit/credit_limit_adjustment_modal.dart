// // New file: credit_limit_adjustment_modal.dart
// import 'package:flutter/material.dart';
//
// import '../../constants.dart';
// import '../customerBase/customer_base.dart';
// import '../main_navigation/main_navigation_base.dart';
//
// class CreditLimitAdjustmentModal extends StatefulWidget {
//   final Customer customer;
//   final EnhancedPOSService posService;
//   final VoidCallback onLimitUpdated;
//
//   const CreditLimitAdjustmentModal({
//     super.key,
//     required this.customer,
//     required this.posService,
//     required this.onLimitUpdated,
//   });
//
//   @override
//   _CreditLimitAdjustmentModalState createState() => _CreditLimitAdjustmentModalState();
// }
//
// class _CreditLimitAdjustmentModalState extends State<CreditLimitAdjustmentModal> {
//   final TextEditingController _limitController = TextEditingController();
//   final TextEditingController _reasonController = TextEditingController();
//   bool _isProcessing = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _limitController.text = widget.customer.creditLimit.toStringAsFixed(2);
//   }
//
//   double get _newLimit => double.tryParse(_limitController.text) ?? 0.0;
//   bool get _isOverBalance => _newLimit < widget.customer.currentBalance;
//
//   void _updateCreditLimit() async {
//     if (_newLimit < 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Credit limit cannot be negative')),
//       );
//       return;
//     }
//
//     if (_isOverBalance) {
//       _showOverBalanceWarning();
//       return;
//     }
//
//     setState(() => _isProcessing = true);
//
//     try {
//       final updatedCustomer = widget.customer.copyWithCredit(
//         creditLimit: _newLimit,
//       );
//
//       await widget.posService.updateCustomer(updatedCustomer);
//       widget.onLimitUpdated();
//       Navigator.pop(context);
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Credit limit updated successfully')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to update credit limit: $e')),
//       );
//     } finally {
//       setState(() => _isProcessing = false);
//     }
//   }
//
//   void _showOverBalanceWarning() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Row(
//           children: [
//             Icon(Icons.warning, color: Colors.orange),
//             SizedBox(width: 8),
//             Text('Credit Limit Warning'),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('The new credit limit is less than the current balance:'),
//             SizedBox(height: 12),
//             Text('Current Balance: ${Constants.CURRENCY_NAME}${widget.customer.currentBalance.toStringAsFixed(2)}'),
//             Text('New Limit: ${Constants.CURRENCY_NAME}${_newLimit.toStringAsFixed(2)}'),
//             Text('Difference: ${Constants.CURRENCY_NAME}${(widget.customer.currentBalance - _newLimit).toStringAsFixed(2)}'),
//             SizedBox(height: 12),
//             Text(
//               'The customer will be over their credit limit. Are you sure you want to proceed?',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _updateCreditLimit();
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//             child: Text('Proceed Anyway'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       child: Container(
//         padding: EdgeInsets.all(24),
//         width: 500,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header
//             Row(
//               children: [
//                 Icon(Icons.credit_card, size: 28, color: Colors.blue),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Adjust Credit Limit',
//                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                       ),
//                       Text(
//                         widget.customer.displayName,
//                         style: TextStyle(color: Colors.grey[600]),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 24),
//
//             // Current Status
//             _buildCurrentStatus(),
//             SizedBox(height: 20),
//
//             // New Limit Input
//             _buildLimitInput(),
//             SizedBox(height: 20),
//
//             // Reason (Optional)
//             _buildReasonInput(),
//             SizedBox(height: 24),
//
//             // Action Buttons
//             _buildActionButtons(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCurrentStatus() {
//     return Card(
//       color: Colors.blue[50],
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             _buildStatusRow('Current Balance', widget.customer.currentBalance),
//             _buildStatusRow('Current Limit', widget.customer.creditLimit),
//             _buildStatusRow('Available Credit', widget.customer.availableCredit),
//             SizedBox(height: 8),
//             LinearProgressIndicator(
//               value: widget.customer.creditUtilization / 100,
//               backgroundColor: Colors.grey[300],
//               valueColor: AlwaysStoppedAnimation(
//                 widget.customer.isOverLimit ? Colors.red : Colors.blue,
//               ),
//             ),
//             SizedBox(height: 4),
//             Text(
//               '${widget.customer.creditUtilization.toStringAsFixed(1)}% Utilized',
//               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildStatusRow(String label, double value) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
//           Text(
//             '${Constants.CURRENCY_NAME}${value.toStringAsFixed(2)}',
//             style: TextStyle(fontWeight: FontWeight.w600),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLimitInput() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'New Credit Limit',
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         SizedBox(height: 8),
//         TextField(
//           controller: _limitController,
//           decoration: InputDecoration(
//             labelText: 'Enter new credit limit',
//             prefixText: Constants.CURRENCY_NAME,
//             border: OutlineInputBorder(),
//             suffixIcon: PopupMenuButton<String>(
//               icon: Icon(Icons.attach_money),
//               itemBuilder: (context) => [
//                 PopupMenuItem(
//                   value: '0',
//                   child: Text('Set to 0 (No Credit)'),
//                 ),
//                 PopupMenuItem(
//                   value: '1000',
//                   child: Text('Set to ${Constants.CURRENCY_NAME}1,000'),
//                 ),
//                 PopupMenuItem(
//                   value: '5000',
//                   child: Text('Set to ${Constants.CURRENCY_NAME}5,000'),
//                 ),
//                 PopupMenuItem(
//                   value: '10000',
//                   child: Text('Set to ${Constants.CURRENCY_NAME}10,000'),
//                 ),
//               ],
//               onSelected: (value) {
//                 _limitController.text = value;
//               },
//             ),
//           ),
//           keyboardType: TextInputType.numberWithOptions(decimal: true),
//           onChanged: (value) => setState(() {}),
//         ),
//         SizedBox(height: 8),
//         if (_isOverBalance)
//           Text(
//             'Warning: New limit is less than current balance',
//             style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
//           ),
//       ],
//     );
//   }
//
//   Widget _buildReasonInput() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Reason for Change (Optional)',
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         SizedBox(height: 8),
//         TextField(
//           controller: _reasonController,
//           decoration: InputDecoration(
//             labelText: 'e.g., "Credit review", "Customer request"',
//             border: OutlineInputBorder(),
//           ),
//           maxLines: 3,
//         ),
//       ],
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
//             onPressed: _isProcessing ? null : _updateCreditLimit,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
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
//               'UPDATE LIMIT',
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
//     _limitController.dispose();
//     _reasonController.dispose();
//     super.dispose();
//   }
// }