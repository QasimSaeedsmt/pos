// // enhanced_checkout_screen.dart
// import 'package:flutter/material.dart';
// import 'package:mpcm/woo_service.dart';
//
// import 'cart_manager.dart';
// import 'app.dart';
//
// class EnhancedCheckoutScreen extends StatefulWidget {
//   final EnhancedCartManager cartManager;
//   final List<CartItem> cartItems;
//
//   const EnhancedCheckoutScreen({
//     Key? key,
//     required this.cartManager,
//     required this.cartItems,
//   }) : super(key: key);
//
//   @override
//   _EnhancedCheckoutScreenState createState() => _EnhancedCheckoutScreenState();
// }
//
// class _EnhancedCheckoutScreenState extends State<EnhancedCheckoutScreen> {
//   final EnhancedWooCommerceService _wooService = EnhancedWooCommerceService();
//   bool _isProcessing = false;
//   Order? _completedOrder;
//   int? _pendingOrderId;
//   String? _errorMessage;
//
//   Future<void> _processOrder() async {
//     if (!mounted) return;
//
//     setState(() {
//       _isProcessing = true;
//       _errorMessage = null;
//       _completedOrder = null;
//       _pendingOrderId = null;
//     });
//
//     try {
//       final result = await _wooService.createOrder(widget.cartItems);
//
//       if (!mounted) return;
//
//       if (result.success) {
//         if (result.isOffline) {
//           setState(() => _pendingOrderId = result.pendingOrderId);
//           _showOfflineSuccessMessage();
//         } else {
//           setState(() => _completedOrder = result.order);
//           _showOnlineSuccessMessage();
//         }
//         widget.cartManager.clearCart();
//       } else {
//         setState(() => _errorMessage = result.error);
//         _showErrorMessage(result.error!);
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _errorMessage = e.toString());
//       _showErrorMessage(e.toString());
//     } finally {
//       if (mounted) {
//         setState(() => _isProcessing = false);
//       }
//     }
//   }
//
//   void _showOnlineSuccessMessage() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(Icons.check_circle, color: Colors.white),
//             SizedBox(width: 8),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('Order Successful!'),
//                   Text(
//                     'Order #${_completedOrder!.number}',
//                     style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.green,
//         duration: Duration(seconds: 4),
//       ),
//     );
//   }
//
//   void _showOfflineSuccessMessage() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(Icons.cloud_off, color: Colors.white),
//             SizedBox(width: 8),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('Order Saved Offline'),
//                   Text(
//                     'Will sync when online',
//                     style: TextStyle(fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.orange,
//         duration: Duration(seconds: 4),
//       ),
//     );
//   }
//
//   void _showErrorMessage(String error) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(Icons.error, color: Colors.white),
//             SizedBox(width: 8),
//             Expanded(child: Text('Checkout failed: $error')),
//           ],
//         ),
//         backgroundColor: Colors.red,
//         duration: Duration(seconds: 5),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final totalAmount = widget.cartManager.totalAmount;
//     final isOnline = _wooService.isOnline;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Checkout'),
//         backgroundColor: Colors.blue[700],
//         actions: [
//           if (!isOnline)
//             Padding(
//               padding: EdgeInsets.only(right: 16),
//               child: Row(
//                 children: [
//                   Icon(Icons.cloud_off, color: Colors.orange, size: 20),
//                   SizedBox(width: 4),
//                   Text('Offline', style: TextStyle(fontSize: 12)),
//                 ],
//               ),
//             ),
//         ],
//       ),
//       body: _completedOrder != null
//           ? OrderSuccessScreen(
//         order: _completedOrder!,
//         onPrintReceipt: _printReceipt,
//         onReturn: _returnToProducts,
//         isOnline: true,
//       )
//           : _pendingOrderId != null
//           ? OfflineOrderSuccessScreen(
//         pendingOrderId: _pendingOrderId!,
//         onPrintReceipt: _printReceipt,
//         onReturn: _returnToProducts,
//       )
//           : Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Connection status banner
//             if (!isOnline)
//               Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.all(12),
//                 margin: EdgeInsets.only(bottom: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.orange[50],
//                   border: Border.all(color: Colors.orange),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.cloud_off, color: Colors.orange, size: 20),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Offline Mode',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               color: Colors.orange[800],
//                             ),
//                           ),
//                           Text(
//                             'Order will be saved locally and synced when online',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.orange[700],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//             Text(
//               'Order Summary',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 16),
//
//             if (_errorMessage != null)
//               Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.all(12),
//                 margin: EdgeInsets.only(bottom: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.red[50],
//                   border: Border.all(color: Colors.red),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   _errorMessage!,
//                   style: TextStyle(color: Colors.red[700]),
//                 ),
//               ),
//
//             Expanded(
//               child: ListView.builder(
//                 itemCount: widget.cartItems.length,
//                 itemBuilder: (context, index) {
//                   final item = widget.cartItems[index];
//                   return ListTile(
//                     leading: Container(
//                       width: 40,
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: Colors.grey[200],
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: item.product.imageUrl != null
//                           ? Image.network(
//                         item.product.imageUrl!,
//                         fit: BoxFit.cover,
//                         errorBuilder: (context, error, stackTrace) {
//                           return Icon(Icons.shopping_bag, size: 20);
//                         },
//                       )
//                           : Icon(Icons.shopping_bag, size: 20),
//                     ),
//                     title: Text(item.product.name),
//                     subtitle: Text('Qty: ${item.quantity}'),
//                     trailing: Text('\$${item.subtotal.toStringAsFixed(2)}'),
//                   );
//                 },
//               ),
//             ),
//             Divider(),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Total Amount:',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   '\$${totalAmount.toStringAsFixed(2)}',
//                   style: TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.green[700],
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 24),
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: _isProcessing
//                   ? ElevatedButton(
//                 onPressed: null,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(color: Colors.white),
//                     SizedBox(width: 12),
//                     Text(isOnline ? 'Processing...' : 'Saving Offline...'),
//                   ],
//                 ),
//               )
//                   : ElevatedButton(
//                 onPressed: _processOrder,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: isOnline ? Colors.green[700] : Colors.orange,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: Text(
//                   isOnline ? 'PROCESS PAYMENT' : 'SAVE OFFLINE ORDER',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _printReceipt() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Receipt sent to printer')),
//     );
//   }
//
//   void _returnToProducts() {
//     Navigator.of(context).popUntil((route) => route.isFirst);
//   }
// }
//
// class OfflineOrderSuccessScreen extends StatelessWidget {
//   final int pendingOrderId;
//   final VoidCallback onPrintReceipt;
//   final VoidCallback onReturn;
//
//   const OfflineOrderSuccessScreen({
//     Key? key,
//     required this.pendingOrderId,
//     required this.onPrintReceipt,
//     required this.onReturn,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.all(24),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.cloud_done,
//             color: Colors.orange,
//             size: 80,
//           ),
//           SizedBox(height: 24),
//           Text(
//             'Order Saved Offline!',
//             style: TextStyle(
//               fontSize: 28,
//               fontWeight: FontWeight.bold,
//               color: Colors.orange[700],
//             ),
//           ),
//           SizedBox(height: 16),
//           Text(
//             'Order #$pendingOrderId',
//             style: TextStyle(fontSize: 18),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Date: ${DateTime.now().toString().split(' ')[0]}',
//             style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//           ),
//           SizedBox(height: 16),
//           Card(
//             child: Padding(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text('Status:', style: TextStyle(fontSize: 18)),
//                       Container(
//                         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                         decoration: BoxDecoration(
//                           color: Colors.orange[100],
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Text(
//                           'PENDING SYNC',
//                           style: TextStyle(
//                             color: Colors.orange[800],
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 8),
//                   Divider(),
//                   SizedBox(height: 8),
//                   Text(
//                     'This order will be automatically synced when you go online',
//                     style: TextStyle(color: Colors.grey[600]),
//                     textAlign: TextAlign.center,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           SizedBox(height: 32),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton(
//                   onPressed: onPrintReceipt,
//                   style: OutlinedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(vertical: 16),
//                   ),
//                   child: Text('PRINT RECEIPT'),
//                 ),
//               ),
//               SizedBox(width: 16),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: onReturn,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue[700],
//                     padding: EdgeInsets.symmetric(vertical: 16),
//                   ),
//                   child: Text('NEW SALE'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }