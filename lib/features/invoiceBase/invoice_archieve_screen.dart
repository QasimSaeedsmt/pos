// // invoice_archive_screen.dart
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:share_plus/share_plus.dart';
//
// import '../../constants.dart';
// import '../../modules/auth/providers/auth_provider.dart';
// import '../../printing/invoice_model.dart';
// import '../../printing/invoice_preview_screen.dart';
// import '../../printing/invoice_service.dart';
// import '../../theme_utils.dart';
// import '../customerBase/customer_base.dart';
// import '../main_navigation/main_navigation_base.dart';
// import '../orderBase/order_base.dart';
//
//
// class InvoiceArchiveScreen extends StatefulWidget {
//   const InvoiceArchiveScreen({super.key});
//
//   @override
//   _InvoiceArchiveScreenState createState() => _InvoiceArchiveScreenState();
// }
//
// class _InvoiceArchiveScreenState extends State<InvoiceArchiveScreen> {
//   final InvoiceService _invoiceService = InvoiceService();
//   final EnhancedPOSService _posService = EnhancedPOSService();
//   final TextEditingController _searchController = TextEditingController();
//
//   List<Invoice> _invoices = [];
//   List<Invoice> _filteredInvoices = [];
//   List<Customer> _customers = [];
//   bool _isLoading = true;
//   bool _hasError = false;
//   String _searchQuery = '';
//   String _selectedStatusFilter = 'all';
//   String _selectedPaymentFilter = 'all';
//   String? _selectedCustomerFilter;
//   DateTime? _startDate;
//   DateTime? _endDate;
//
//   // Filters
//   final List<String> _statusFilters = ['all', 'paid', 'pending', 'overdue', 'partial', 'credited', 'refunded'];
//   final List<String> _paymentFilters = ['all', 'cash', 'credit', 'easypaisa', 'bank_transfer', 'card', 'mixed'];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadAllData();
//   }
//
//   Future<void> _loadAllData() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _hasError = false;
//       });
//
//       // Load data in parallel
//       await Future.wait([
//         _loadInvoices(),
//         _loadCustomers(),
//       ]);
//
//       _applyFilters();
//
//     } catch (e) {
//       print('Error loading data: $e');
//       setState(() {
//         _hasError = true;
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _loadInvoices() async {
//     try {
//       // Load from multiple sources in parallel
//       final results = await Future.wait([
//         _loadInvoicesFromFirestore(),
//         _loadInvoicesFromOrders(),
//       ], eagerError: true);
//
//       final firestoreInvoices = results[0] as List<Invoice>;
//       final orderInvoices = results[1] as List<Invoice>;
//
//       // Merge and deduplicate
//       final allInvoices = [...firestoreInvoices, ...orderInvoices];
//       _invoices = _removeDuplicateInvoices(allInvoices);
//
//     } catch (e) {
//       print('Error loading invoices: $e');
//       rethrow;
//     }
//   }
//
//   Future<void> _loadCustomers() async {
//     try {
//       _customers = await _posService.getAllCustomers();
//     } catch (e) {
//       print('Error loading customers: $e');
//       _customers = [];
//     }
//   }
//
//   List<Invoice> _removeDuplicateInvoices(List<Invoice> invoices) {
//     final Map<String, Invoice> uniqueInvoices = {};
//
//     for (final invoice in invoices) {
//       final key = '${invoice.invoiceNumber}_${invoice.issueDate.millisecondsSinceEpoch}';
//       if (!uniqueInvoices.containsKey(key)) {
//         uniqueInvoices[key] = invoice;
//       } else {
//         // Prefer invoices with more complete data
//         final existing = uniqueInvoices[key]!;
//         if (_getInvoiceCompletenessScore(invoice) > _getInvoiceCompletenessScore(existing)) {
//           uniqueInvoices[key] = invoice;
//         }
//       }
//     }
//
//     return uniqueInvoices.values.toList()
//       ..sort((a, b) => b.issueDate.compareTo(a.issueDate));
//   }
//
//   int _getInvoiceCompletenessScore(Invoice invoice) {
//     int score = 0;
//     if (invoice.items.isNotEmpty) score += 10;
//     if (invoice.customer != null) score += 5;
//     if (invoice.hasEnhancedPricing) score += 3;
//     if (invoice.totalAmount > 0) score += 2;
//     return score;
//   }
//
//   Future<List<Invoice>> _loadInvoicesFromFirestore() async {
//     try {
//       final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
//       final tenantId = authProvider.currentUser?.tenantId;
//
//       if (tenantId == null) return [];
//
//       final invoicesRef = FirebaseFirestore.instance
//           .collection('tenants')
//           .doc(tenantId)
//           .collection('invoices');
//
//       final snapshot = await invoicesRef
//           .orderBy('issueDate', descending: true)
//           .limit(2000)
//           .get();
//
//       return snapshot.docs.map((doc) {
//         try {
//           final data = doc.data();
//           return Invoice.fromMap(data);
//         } catch (e) {
//           print('Error parsing invoice document ${doc.id}: $e');
//           return _createErrorInvoice('Firestore Error: $e');
//         }
//       }).where((invoice) => invoice.invoiceNumber != 'ERROR').toList();
//     } catch (e) {
//       print('Error loading from Firestore: $e');
//       return [];
//     }
//   }
//
//   Future<List<Invoice>> _loadInvoicesFromOrders() async {
//     try {
//       final orders = await _posService.getRecentOrders(limit: 1000);
//       final businessInfo = await _posService.getBusinessInfo();
//       final invoiceSettings = await _posService.getInvoiceSettings();
//
//       final List<Invoice> generatedInvoices = [];
//
//       // Process orders in batches to avoid overwhelming the system
//       for (int i = 0; i < orders.length; i += 50) {
//         final batch = orders.sublist(i, i + 50 > orders.length ? orders.length : i + 50);
//         final batchInvoices = await _processOrderBatch(batch, businessInfo, invoiceSettings);
//         generatedInvoices.addAll(batchInvoices);
//
//         // Small delay to prevent overwhelming the system
//         if (i + 50 < orders.length) {
//           await Future.delayed(Duration(milliseconds: 100));
//         }
//       }
//
//       return generatedInvoices;
//     } catch (e) {
//       print('Error generating invoices from orders: $e');
//       return [];
//     }
//   }
//
//   Future<List<Invoice>> _processOrderBatch(
//       List<AppOrder> orders,
//       Map<String, dynamic> businessInfo,
//       Map<String, dynamic> invoiceSettings
//       ) async {
//     final List<Invoice> batchInvoices = [];
//
//     for (final order in orders) {
//       try {
//         final invoice = await _createInvoiceFromOrder(order, businessInfo, invoiceSettings);
//         if (invoice != null) {
//           batchInvoices.add(invoice);
//         }
//       } catch (e) {
//         print('Error creating invoice for order ${order.id}: $e');
//       }
//     }
//
//     return batchInvoices;
//   }
//
//   Future<Invoice?> _createInvoiceFromOrder(
//       AppOrder order,
//       Map<String, dynamic> businessInfo,
//       Map<String, dynamic> invoiceSettings
//       ) async {
//     try {
//       // Extract real data from order
//       final enhancedData = _extractRealEnhancedDataFromOrder(order);
//       final customer = await _getCustomerForOrder(order);
//       final paymentInfo = _extractRealPaymentInfo(order, enhancedData);
//
//       final invoice = Invoice.fromOrder(
//         order,
//         customer,
//         businessInfo,
//         invoiceSettings,
//         templateType: invoiceSettings['defaultTemplate'] ?? 'traditional',
//         enhancedData: enhancedData,
//       ).copyWith(
//         status: paymentInfo['status'],
//         paymentMethod: paymentInfo['method'],
//       );
//
//       return invoice;
//     } catch (e) {
//       print('Error creating invoice from order ${order.id}: $e');
//       return null;
//     }
//   }
//
//   Map<String, dynamic> _extractRealEnhancedDataFromOrder(AppOrder order) {
//     try {
//       final Map<String, dynamic> enhancedData = {
//         'cartData': {
//           'items': [],
//           'subtotal': order.total,
//           'totalAmount': order.total,
//           'has_enhanced_pricing': false,
//         },
//         'orderSource': 'firestore',
//         'extractedAt': DateTime.now().toIso8601String(),
//       };
//
//       // Extract real line items with proper data
//       if (order.lineItems.isNotEmpty) {
//         final enhancedItems = order.lineItems.map((item) {
//           if (item is Map<String, dynamic>) {
//             return {
//               'productId': item['productId'] ?? item['id'] ?? 'unknown',
//               'productName': item['productName'] ?? item['name'] ?? 'Unknown Product',
//               'quantity': (item['quantity'] as num?)?.toInt() ?? 1,
//               'price': (item['price'] as num?)?.toDouble() ?? 0.0,
//               'base_price': item['base_price'] ?? item['originalPrice'] ?? item['price'],
//               'manual_discount': item['manual_discount'] ?? item['discountAmount'] ?? 0.0,
//               'manual_discount_percent': item['manual_discount_percent'] ?? item['discountPercent'] ?? 0.0,
//               'discount_amount': item['discount_amount'] ?? item['discount'] ?? 0.0,
//               'base_subtotal': item['base_subtotal'] ?? ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1),
//               'final_subtotal': item['final_subtotal'] ?? item['total'] ?? ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1),
//               'has_manual_discount': item['has_manual_discount'] ?? (item['discountAmount'] != null && (item['discountAmount'] as num).toDouble() > 0),
//             };
//           }
//           return item;
//         }).toList();
//
//         enhancedData['cartData']['items'] = enhancedItems;
//
//         // Check if we have enhanced pricing
//         final hasEnhancedPricing = order.lineItems.any((item) =>
//         item is Map && (
//             item.containsKey('base_price') ||
//                 item.containsKey('manual_discount') ||
//                 item.containsKey('discount_amount')
//         )
//         );
//
//         enhancedData['cartData']['has_enhanced_pricing'] = hasEnhancedPricing;
//       }
//
//       // Extract payment and credit information
//       if (order.lineItems.isNotEmpty && order.lineItems[0] is Map) {
//         final firstItem = order.lineItems[0] as Map<String, dynamic>;
//
//         enhancedData['paymentMethod'] = firstItem['paymentMethod'] ??
//             firstItem['payment_method'] ??
//             'cash';
//
//         enhancedData['creditData'] = firstItem['creditData'] ??
//             firstItem['credit_data'] ??
//             _extractCreditDataFromOrder(firstItem);
//       }
//
//       return enhancedData;
//     } catch (e) {
//       print('Error extracting enhanced data: $e');
//       return {};
//     }
//   }
//
//   Map<String, dynamic> _extractCreditDataFromOrder(Map<String, dynamic> orderData) {
//     final creditData = <String, dynamic>{};
//
//     // Look for credit-related fields
//     if (orderData.containsKey('creditAmount') || orderData.containsKey('credit_amount')) {
//       creditData['creditAmount'] = (orderData['creditAmount'] ?? orderData['credit_amount'] as num?)?.toDouble() ?? 0.0;
//     }
//
//     if (orderData.containsKey('paidAmount') || orderData.containsKey('paid_amount')) {
//       creditData['paidAmount'] = (orderData['paidAmount'] ?? orderData['paid_amount'] as num?)?.toDouble() ?? 0.0;
//     }
//
//     if (orderData.containsKey('dueDate') || orderData.containsKey('due_date')) {
//       final dueDate = orderData['dueDate'] ?? orderData['due_date'];
//       if (dueDate is Timestamp) {
//         creditData['dueDate'] = dueDate.toDate().toIso8601String();
//       } else if (dueDate is String) {
//         creditData['dueDate'] = dueDate;
//       }
//     }
//
//     return creditData.isEmpty ? {} : creditData;
//   }
//
//   Future<Customer?> _getCustomerForOrder(AppOrder order) async {
//     try {
//       // Look for customer ID in order data
//       String? customerId;
//
//       for (final item in order.lineItems) {
//         if (item is Map) {
//           customerId = item['customerId'] ?? item['customer_id'];
//           if (customerId != null) break;
//         }
//       }
//
//       if (customerId != null) {
//         return await _posService.getCustomerById(customerId);
//       }
//
//       // Try to find customer by email or phone from order data
//       if (order.lineItems.isNotEmpty && order.lineItems[0] is Map) {
//         final firstItem = order.lineItems[0] as Map<String, dynamic>;
//         final customerEmail = firstItem['customerEmail'] ?? firstItem['customer_email'];
//         final customerPhone = firstItem['customerPhone'] ?? firstItem['customer_phone'];
//
//         if (customerEmail != null) {
//           return await _posService.getCustomerByEmail(customerEmail);
//         }
//
//         if (customerPhone != null) {
//           final allCustomers = await _posService.getAllCustomers();
//           return allCustomers.firstWhere(
//                 (customer) => customer.phone == customerPhone,
//             orElse: () => null as Customer,
//           );
//         }
//       }
//
//       return null;
//     } catch (e) {
//       print('Error getting customer for order: $e');
//       return null;
//     }
//   }
//
//   Map<String, String> _extractRealPaymentInfo(AppOrder order, Map<String, dynamic> enhancedData) {
//     String status = 'paid';
//     String method = 'cash';
//
//     try {
//       // Extract from enhanced data first
//       if (enhancedData['paymentMethod'] != null) {
//         method = enhancedData['paymentMethod'].toString();
//       }
//
//       if (enhancedData['creditData'] != null && enhancedData['creditData'].isNotEmpty) {
//         final creditData = enhancedData['creditData'];
//         final paidAmount = (creditData['paidAmount'] as num?)?.toDouble() ?? 0.0;
//         final creditAmount = (creditData['creditAmount'] as num?)?.toDouble() ?? 0.0;
//         final totalAmount = order.total;
//
//         if (paidAmount == 0 && creditAmount > 0) {
//           status = 'credited';
//         } else if (paidAmount > 0 && paidAmount < totalAmount) {
//           status = 'partial';
//         } else if (paidAmount == totalAmount) {
//           status = 'paid';
//         }
//       }
//
//       // Extract from order line items as fallback
//       if (order.lineItems.isNotEmpty && order.lineItems[0] is Map) {
//         final firstItem = order.lineItems[0] as Map<String, dynamic>;
//
//         if (method == 'cash') {
//           method = firstItem['paymentMethod'] ?? firstItem['payment_method'] ?? 'cash';
//         }
//
//         if (status == 'paid') {
//           final orderStatus = firstItem['status'] ?? firstItem['paymentStatus'];
//           if (orderStatus != null) {
//             status = orderStatus.toString().toLowerCase();
//           }
//         }
//       }
//
//       // Validate status
//       if (!_statusFilters.contains(status)) {
//         status = 'paid'; // default fallback
//       }
//
//     } catch (e) {
//       print('Error extracting payment info: $e');
//     }
//
//     return {'status': status, 'method': method};
//   }
//
//   Invoice _createErrorInvoice(String error) {
//     return Invoice(
//       id: 'error_${DateTime.now().millisecondsSinceEpoch}',
//       orderId: '',
//       invoiceNumber: 'ERROR',
//       issueDate: DateTime.now(),
//       dueDate: null,
//       customer: null,
//       items: [],
//       subtotal: 0,
//       taxAmount: 0,
//       discountAmount: 0,
//       totalAmount: 0,
//       paymentMethod: 'cash',
//       status: 'error',
//       notes: error,
//       businessInfo: {},
//       invoiceSettings: {},
//       templateType: 'traditional',
//     );
//   }
//
//   void _applyFilters() {
//     if (_invoices.isEmpty) {
//       _filteredInvoices = [];
//       return;
//     }
//
//     List<Invoice> filtered = List.from(_invoices);
//
//     // Apply search filter - very efficient matching
//     if (_searchQuery.trim().isNotEmpty) {
//       final query = _searchQuery.trim().toLowerCase();
//       filtered = filtered.where((invoice) => _efficientSearchMatch(invoice, query)).toList();
//     }
//
//     // Apply status filter
//     if (_selectedStatusFilter != 'all') {
//       filtered = filtered.where((invoice) => invoice.status == _selectedStatusFilter).toList();
//     }
//
//     // Apply payment method filter
//     if (_selectedPaymentFilter != 'all') {
//       filtered = filtered.where((invoice) =>
//       _normalizePaymentMethod(invoice.paymentMethod) == _selectedPaymentFilter
//       ).toList();
//     }
//
//     // Apply customer filter
//     if (_selectedCustomerFilter != null) {
//       filtered = filtered.where((invoice) =>
//       invoice.customer?.id == _selectedCustomerFilter
//       ).toList();
//     }
//
//     // Apply date filter
//     if (_startDate != null) {
//       final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
//       filtered = filtered.where((invoice) =>
//           invoice.issueDate.isAfter(start.subtract(Duration(days: 1)))
//       ).toList();
//     }
//
//     if (_endDate != null) {
//       final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day).add(Duration(days: 1));
//       filtered = filtered.where((invoice) =>
//           invoice.issueDate.isBefore(end)
//       ).toList();
//     }
//
//     setState(() {
//       _filteredInvoices = filtered;
//     });
//   }
//
//   bool _efficientSearchMatch(Invoice invoice, String query) {
//     // Quick exact matches first
//     if (invoice.invoiceNumber.toLowerCase().contains(query)) return true;
//     if (invoice.orderId.toLowerCase().contains(query)) return true;
//
//     // Customer matches
//     if (invoice.customer != null) {
//       if (invoice.customer!.fullName.toLowerCase().contains(query)) return true;
//       if (invoice.customer!.email.toLowerCase().contains(query)) return true;
//       if (invoice.customer!.phone.contains(query)) return true;
//     }
//
//     // Amount matches (exact and partial)
//     if (invoice.totalAmount.toString().contains(query)) return true;
//     if (query.contains(Constants.CURRENCY_NAME.toLowerCase())) {
//       final amountQuery = query.replaceAll(Constants.CURRENCY_NAME.toLowerCase(), '').trim();
//       if (amountQuery.isNotEmpty && invoice.totalAmount.toString().contains(amountQuery)) return true;
//     }
//
//     // Item name matches
//     for (final item in invoice.items) {
//       if (item.name.toLowerCase().contains(query)) return true;
//       if (item.description.toLowerCase().contains(query)) return true;
//     }
//
//     // Payment method matches
//     if (_normalizePaymentMethod(invoice.paymentMethod).contains(query)) return true;
//
//     // Status matches
//     if (invoice.status.toLowerCase().contains(query)) return true;
//
//     return false;
//   }
//
//   String _normalizePaymentMethod(String method) {
//     final normalized = method.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_');
//
//     // Map common variations to standard values
//     if (normalized.contains('easy') || normalized.contains('paisa')) return 'easypaisa';
//     if (normalized.contains('bank') || normalized.contains('transfer')) return 'bank_transfer';
//     if (normalized.contains('card') || normalized.contains('debit') || normalized.contains('credit')) return 'card';
//     if (normalized.contains('cash')) return 'cash';
//     if (normalized.contains('mixed') || normalized.contains('multiple')) return 'mixed';
//
//     return normalized;
//   }
//
//   void _showAdvancedFilterDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setDialogState) {
//           return AlertDialog(
//             title: Row(
//               children: [
//                 Icon(Icons.filter_alt, color: ThemeUtils.primary(context)),
//                 SizedBox(width: 8),
//                 Text('Advanced Filters'),
//               ],
//             ),
//             content: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Status Filter
//                   _buildFilterSection(
//                     'Payment Status',
//                     _selectedStatusFilter,
//                     _statusFilters,
//                         (value) => setDialogState(() => _selectedStatusFilter = value!),
//                   ),
//
//                   SizedBox(height: 16),
//
//                   // Payment Method Filter
//                   _buildFilterSection(
//                     'Payment Method',
//                     _selectedPaymentFilter,
//                     _paymentFilters,
//                         (value) => setDialogState(() => _selectedPaymentFilter = value!),
//                     displayMapper: _getPaymentMethodDisplayName,
//                   ),
//
//                   SizedBox(height: 16),
//
//                   // Customer Filter
//                   _buildCustomerFilterSection(setDialogState),
//
//                   SizedBox(height: 16),
//
//                   // Date Range
//                   _buildDateFilterSection(setDialogState),
//                 ],
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   setDialogState(() {
//                     _selectedStatusFilter = 'all';
//                     _selectedPaymentFilter = 'all';
//                     _selectedCustomerFilter = null;
//                     _startDate = null;
//                     _endDate = null;
//                   });
//                 },
//                 child: Text('Reset All'),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _applyFilters();
//                 },
//                 child: Text('Apply Filters'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildFilterSection(
//       String title,
//       String currentValue,
//       List<String> options,
//       Function(String?) onChanged, {
//         String Function(String)? displayMapper,
//       }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//         ),
//         SizedBox(height: 8),
//         DropdownButtonFormField<String>(
//           value: currentValue,
//           isExpanded: true,
//           decoration: InputDecoration(
//             border: OutlineInputBorder(),
//             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           ),
//           items: options.map((value) {
//             final displayValue = displayMapper != null ? displayMapper(value) : _getStatusDisplayName(value);
//             return DropdownMenuItem(
//               value: value,
//               child: Text(displayValue),
//             );
//           }).toList(),
//           onChanged: onChanged,
//         ),
//       ],
//     );
//   }
//
//   Widget _buildCustomerFilterSection(Function setDialogState) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Customer',
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//         ),
//         SizedBox(height: 8),
//         DropdownButtonFormField<String>(
//           value: _selectedCustomerFilter,
//           isExpanded: true,
//           decoration: InputDecoration(
//             border: OutlineInputBorder(),
//             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             hintText: 'All Customers',
//           ),
//           items: [
//             DropdownMenuItem(
//               value: null,
//               child: Text('All Customers', style: TextStyle(color: Colors.grey)),
//             ),
//             ..._customers.map((customer) {
//               return DropdownMenuItem(
//                 value: customer.id,
//                 child: Text(
//                   customer.fullName,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               );
//             }).toList(),
//           ],
//           onChanged: (value) => setDialogState(() => _selectedCustomerFilter = value),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDateFilterSection(Function setDialogState) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Date Range',
//           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//         ),
//         SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(
//               child: _buildDatePicker(
//                 'From Date',
//                 _startDate,
//                     () => _selectStartDate(context, setDialogState),
//               ),
//             ),
//             SizedBox(width: 8),
//             Expanded(
//               child: _buildDatePicker(
//                 'To Date',
//                 _endDate,
//                     () => _selectEndDate(context, setDialogState),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       child: InputDecorator(
//         decoration: InputDecoration(
//           labelText: label,
//           border: OutlineInputBorder(),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Any date',
//               style: TextStyle(
//                 color: date != null ? Colors.black : Colors.grey,
//               ),
//             ),
//             Icon(Icons.calendar_today, size: 16, color: Colors.grey),
//           ],
//         ),
//       ),
//     );
//   }
//
//   String _getStatusDisplayName(String status) {
//     switch (status) {
//       case 'all': return 'All Statuses';
//       case 'paid': return 'Paid';
//       case 'pending': return 'Pending Payment';
//       case 'overdue': return 'Overdue';
//       case 'partial': return 'Partially Paid';
//       case 'credited': return 'Credit Sale';
//       case 'refunded': return 'Refunded';
//       default: return status.toUpperCase();
//     }
//   }
//
//   String _getPaymentMethodDisplayName(String method) {
//     switch (method) {
//       case 'all': return 'All Methods';
//       case 'cash': return 'Cash';
//       case 'credit': return 'Credit Account';
//       case 'easypaisa': return 'Easypaisa';
//       case 'bank_transfer': return 'Bank Transfer';
//       case 'card': return 'Card Payment';
//       case 'mixed': return 'Mixed Payment';
//       default: return method.replaceAll('_', ' ').toTitleCase();
//     }
//   }
//
//   Future<void> _selectStartDate(BuildContext context, Function setDialogState) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _startDate ?? DateTime.now().subtract(Duration(days: 30)),
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setDialogState(() {
//         _startDate = picked;
//       });
//     }
//   }
//
//   Future<void> _selectEndDate(BuildContext context, Function setDialogState) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _endDate ?? DateTime.now(),
//       firstDate: _startDate ?? DateTime(2020),
//       lastDate: DateTime.now().add(Duration(days: 365)),
//     );
//     if (picked != null) {
//       setDialogState(() {
//         _endDate = picked;
//       });
//     }
//   }
//
//   void _showInvoiceActions(Invoice invoice) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: Icon(Icons.visibility, color: Colors.blue),
//               title: Text('Preview Invoice'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _previewInvoice(invoice);
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.print, color: Colors.green),
//               title: Text('Print Traditional (A4)'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _printInvoice(invoice, 'traditional');
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.receipt, color: Colors.orange),
//               title: Text('Print Thermal Receipt'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _printInvoice(invoice, 'thermal');
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.picture_as_pdf, color: Colors.red),
//               title: Text('Generate PDF'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _generatePdf(invoice);
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.share, color: Colors.purple),
//               title: Text('Share Invoice'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _shareInvoice(invoice);
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.receipt_long, color: Colors.teal),
//               title: Text('View Order Details'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _viewOrderDetails(invoice);
//               },
//             ),
//             if (invoice.hasEnhancedPricing)
//               ListTile(
//                 leading: Icon(Icons.analytics, color: Colors.indigo),
//                 title: Text('View Pricing Breakdown'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _showPricingBreakdown(invoice);
//                 },
//               ),
//             Divider(),
//             ListTile(
//               leading: Icon(Icons.close, color: Colors.grey),
//               title: Text('Cancel'),
//               onTap: () => Navigator.pop(context),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _previewInvoice(Invoice invoice) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => InvoicePreviewScreen(invoice: invoice),
//       ),
//     );
//   }
//
//   Future<void> _printInvoice(Invoice invoice, String templateType) async {
//     try {
//       // Create a copy with the desired template type
//       final invoiceToPrint = invoice.copyWith(templateType: templateType);
//
//       await _invoiceService.printInvoice(invoiceToPrint);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Invoice sent to printer ($templateType)'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to print: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _generatePdf(Invoice invoice) async {
//     try {
//       final pdfFile = await _invoiceService.generatePdfInvoice(invoice);
//
//       // Show success dialog with file path
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: Text('PDF Generated Successfully'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Invoice: ${invoice.invoiceNumber}'),
//               SizedBox(height: 8),
//               Text('File saved to:'),
//               Text(
//                 pdfFile.path,
//                 style: TextStyle(fontSize: 12, color: Colors.grey),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('OK'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _shareInvoice(invoice);
//               },
//               child: Text('Share PDF'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to generate PDF: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   Future<void> _shareInvoice(Invoice invoice) async {
//     try {
//       final pdfFile = await _invoiceService.generatePdfInvoice(invoice);
//       await Share.shareXFiles(
//         [XFile(pdfFile.path)],
//         text: 'Invoice ${invoice.invoiceNumber} - ${Constants.CURRENCY_NAME}${invoice.totalAmount.toStringAsFixed(2)}',
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to share invoice: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   void _viewOrderDetails(Invoice invoice) async {
//     try {
//       // Try to get the order details
//       final order = await _posService.getOrderById(invoice.orderId);
//
//       if (order != null) {
//         _showOrderDetailsDialog(order, invoice);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Order details not found for ${invoice.orderId}'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading order details: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   void _showOrderDetailsDialog(AppOrder order, Invoice invoice) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Row(
//           children: [
//             Icon(Icons.receipt_long, color: ThemeUtils.primary(context)),
//             SizedBox(width: 8),
//             Text('Order Details'),
//           ],
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _buildDetailRow('Order Number', order.number),
//               _buildDetailRow('Order Date', DateFormat('MMM dd, yyyy HH:mm').format(order.dateCreated)),
//               _buildDetailRow('Order Total', '${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}'),
//               _buildDetailRow('Invoice Number', invoice.invoiceNumber),
//               _buildDetailRow('Payment Status', invoice.status.toUpperCase()),
//               _buildDetailRow('Payment Method', _getPaymentMethodDisplayName(invoice.paymentMethod)),
//
//               SizedBox(height: 16),
//               Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
//               ...order.lineItems.take(5).map((item) {
//                 final productName = item['productName'] ?? 'Unknown Product';
//                 final quantity = item['quantity'] ?? 1;
//                 final price = (item['price'] as num?)?.toDouble() ?? 0.0;
//                 return Padding(
//                   padding: EdgeInsets.only(top: 4),
//                   child: Text('• $productName x$quantity - ${Constants.CURRENCY_NAME}${price.toStringAsFixed(2)}'),
//                 );
//               }).toList(),
//
//               if (order.lineItems.length > 5)
//                 Text('... and ${order.lineItems.length - 5} more items'),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailRow(String label, String value) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               '$label:',
//               style: TextStyle(fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Text(value),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showPricingBreakdown(Invoice invoice) {
//     final discounts = invoice.allDiscounts;
//     final totalSavings = invoice.totalSavings;
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Pricing Breakdown'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildBreakdownRow('Gross Amount', invoice.subtotal),
//               if (discounts.isNotEmpty) ...[
//                 SizedBox(height: 8),
//                 Text('Discounts:', style: TextStyle(fontWeight: FontWeight.bold)),
//                 ...discounts.entries.map((entry) =>
//                     _buildBreakdownRow(
//                       _getDiscountLabel(entry.key),
//                       -entry.value,
//                       isDiscount: true,
//                     )
//                 ).toList(),
//               ],
//               _buildBreakdownRow('Net Amount', invoice.netAmount, isEmphasized: true),
//               if (invoice.taxAmount > 0)
//                 _buildBreakdownRow('Tax', invoice.taxAmount),
//               if (invoice.shippingAmount > 0)
//                 _buildBreakdownRow('Shipping', invoice.shippingAmount),
//               if (invoice.tipAmount > 0)
//                 _buildBreakdownRow('Tip', invoice.tipAmount),
//               Divider(),
//               _buildBreakdownRow('Final Total', invoice.totalAmount, isTotal: true),
//               if (totalSavings > 0) ...[
//                 SizedBox(height: 8),
//                 Container(
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.green[50],
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Total Savings:',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.green[800],
//                         ),
//                       ),
//                       Text(
//                         '-${Constants.CURRENCY_NAME}${totalSavings.toStringAsFixed(2)}',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.green[800],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _getDiscountLabel(String discountType) {
//     switch (discountType) {
//       case 'item_discounts': return 'Item Discounts';
//       case 'cart_discount': return 'Cart Discount';
//       case 'additional_discount': return 'Additional Discount';
//       case 'settings_discount': return 'Standard Discount';
//       case 'legacy_discount': return 'Discount';
//       default: return discountType.replaceAll('_', ' ').toTitleCase();
//     }
//   }
//
//   Widget _buildBreakdownRow(String label, double amount, {bool isDiscount = false, bool isTotal = false, bool isEmphasized = false}) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: isEmphasized || isTotal ? FontWeight.bold : FontWeight.normal,
//               color: isDiscount ? Colors.green : Colors.black,
//             ),
//           ),
//           Text(
//             '${isDiscount ? '-' : ''}${Constants.CURRENCY_NAME}${amount.abs().toStringAsFixed(2)}',
//             style: TextStyle(
//               fontWeight: isEmphasized || isTotal ? FontWeight.bold : FontWeight.normal,
//               color: isDiscount ? Colors.green : (isTotal ? Colors.green[700] : Colors.black),
//               fontSize: isTotal ? 16 : 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInvoiceCard(Invoice invoice) {
//     final isCredit = invoice.status == 'credited' || invoice.status == 'partial';
//     final isOverdue = invoice.status == 'overdue';
//     final customerName = invoice.customer?.fullName ?? 'Walk-in Customer';
//
//     return Card(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       elevation: 2,
//       child: InkWell(
//         onTap: () => _showInvoiceActions(invoice),
//         onLongPress: () => _showInvoiceActions(invoice),
//         child: Padding(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header row
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Text(
//                       invoice.invoiceNumber,
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: ThemeUtils.primary(context),
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: _getStatusColor(invoice.status),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       _getStatusDisplayName(invoice.status).toUpperCase(),
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 8),
//
//               // Customer info - Prominently displayed
//               Row(
//                 children: [
//                   Icon(Icons.person, size: 16, color: Colors.blue),
//                   SizedBox(width: 6),
//                   Expanded(
//                     child: Text(
//                       customerName,
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.blue[700],
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//
//               SizedBox(height: 6),
//
//               // Order and date info
//               Row(
//                 children: [
//                   Icon(Icons.receipt, size: 14, color: Colors.grey),
//                   SizedBox(width: 4),
//                   Text(
//                     'Order: ${invoice.orderId}',
//                     style: TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                   Spacer(),
//                   Icon(Icons.calendar_today, size: 14, color: Colors.grey),
//                   SizedBox(width: 4),
//                   Text(
//                     DateFormat('MMM dd, yyyy').format(invoice.issueDate),
//                     style: TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ],
//               ),
//
//               SizedBox(height: 6),
//
//               // Payment method
//               Row(
//                 children: [
//                   Icon(Icons.payment, size: 14, color: Colors.grey),
//                   SizedBox(width: 4),
//                   Text(
//                     _getPaymentMethodDisplayName(invoice.paymentMethod),
//                     style: TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ],
//               ),
//
//               SizedBox(height: 8),
//
//               // Amount and template
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '${Constants.CURRENCY_NAME}${invoice.totalAmount.toStringAsFixed(2)}',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: isCredit ? Colors.orange : Colors.green[700],
//                         ),
//                       ),
//                       if (isCredit)
//                         Text(
//                           'Credit Sale',
//                           style: TextStyle(
//                             fontSize: 10,
//                             color: Colors.orange,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                     ],
//                   ),
//                   Row(
//                     children: [
//                       Container(
//                         padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: Colors.grey[100],
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(
//                           invoice.templateType == 'thermal' ? 'Receipt' : 'A4',
//                           style: TextStyle(fontSize: 10, color: Colors.grey[600]),
//                         ),
//                       ),
//                       SizedBox(width: 8),
//                       if (invoice.hasEnhancedPricing)
//                         Container(
//                           padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: Colors.green[50],
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Icon(Icons.discount, size: 12, color: Colors.green),
//                         ),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Color _getStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'paid':
//         return Colors.green;
//       case 'pending':
//         return Colors.orange;
//       case 'overdue':
//         return Colors.red;
//       case 'partial':
//         return Colors.blue;
//       case 'credited':
//         return Colors.purple;
//       case 'refunded':
//         return Colors.grey;
//       default:
//         return Colors.grey;
//     }
//   }
//
//   Widget _buildStatsOverview() {
//     final totalInvoices = _filteredInvoices.length;
//     final totalAmount = _filteredInvoices.fold(0.0, (sum, invoice) => sum + invoice.totalAmount);
//     final paidInvoices = _filteredInvoices.where((inv) => inv.status == 'paid').length;
//     final creditInvoices = _filteredInvoices.where((inv) => inv.status == 'credited' || inv.status == 'partial').length;
//
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             ThemeUtils.primary(context)!.withOpacity(0.8),
//             ThemeUtils.primary(context)!.withOpacity(0.6),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _buildStatItem('Total', totalInvoices.toString(), Icons.receipt),
//           _buildStatItem('Amount', '${Constants.CURRENCY_NAME}${totalAmount.toStringAsFixed(0)}', Icons.attach_money),
//           _buildStatItem('Paid', paidInvoices.toString(), Icons.check_circle),
//           _buildStatItem('Credit', creditInvoices.toString(), Icons.credit_card),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatItem(String label, String value, IconData icon) {
//     return Column(
//       children: [
//         Icon(icon, color: Colors.white, size: 20),
//         SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 2),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.8),
//             fontSize: 12,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSearchHeader() {
//     return Padding(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         children: [
//           // Search Bar
//           TextField(
//             controller: _searchController,
//             decoration: InputDecoration(
//               hintText: 'Search invoices, customers, amounts...',
//               prefixIcon: Icon(Icons.search),
//               suffixIcon: _searchQuery.isNotEmpty ? IconButton(
//                 icon: Icon(Icons.clear),
//                 onPressed: () {
//                   _searchController.clear();
//                   setState(() => _searchQuery = '');
//                   _applyFilters();
//                 },
//               ) : null,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             onChanged: (value) {
//               setState(() => _searchQuery = value);
//               _applyFilters();
//             },
//           ),
//           SizedBox(height: 12),
//
//           // Quick Filter Chips
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               children: [
//                 _buildFilterChip('All', 'all', _selectedStatusFilter, (v) {
//                   setState(() => _selectedStatusFilter = v);
//                   _applyFilters();
//                 }),
//                 _buildFilterChip('Paid', 'paid', _selectedStatusFilter, (v) {
//                   setState(() => _selectedStatusFilter = v);
//                   _applyFilters();
//                 }),
//                 _buildFilterChip('Credit', 'credited', _selectedStatusFilter, (v) {
//                   setState(() => _selectedStatusFilter = v);
//                   _applyFilters();
//                 }),
//                 _buildFilterChip('Pending', 'pending', _selectedStatusFilter, (v) {
//                   setState(() => _selectedStatusFilter = v);
//                   _applyFilters();
//                 }),
//                 InkWell(
//                   onTap: _showAdvancedFilterDialog,
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: ThemeUtils.primary(context)!),
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(Icons.filter_alt, size: 16, color: ThemeUtils.primary(context)),
//                         SizedBox(width: 4),
//                         Text('More Filters'),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFilterChip(String label, String value, String selectedValue, Function(String) onSelected) {
//     final isSelected = selectedValue == value;
//     return Container(
//       margin: EdgeInsets.only(right: 8),
//       child: ChoiceChip(
//         label: Text(label),
//         selected: isSelected,
//         onSelected: (selected) => onSelected(selected ? value : 'all'),
//         selectedColor: ThemeUtils.primary(context),
//         labelStyle: TextStyle(
//           color: isSelected ? Colors.white : Colors.black,
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Invoice Archive'),
//         backgroundColor: ThemeUtils.primary(context),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: _loadAllData,
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Search and Quick Filters
//           _buildSearchHeader(),
//
//           // Stats Overview
//           _buildStatsOverview(),
//
//           // Results count
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   '${_filteredInvoices.length} invoice(s)',
//                   style: TextStyle(
//                     color: Colors.grey[600],
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 if (_hasActiveFilters)
//                   InkWell(
//                     onTap: () {
//                       _searchController.clear();
//                       setState(() {
//                         _searchQuery = '';
//                         _selectedStatusFilter = 'all';
//                         _selectedPaymentFilter = 'all';
//                         _selectedCustomerFilter = null;
//                         _startDate = null;
//                         _endDate = null;
//                       });
//                       _applyFilters();
//                     },
//                     child: Row(
//                       children: [
//                         Icon(Icons.clear, size: 16, color: Colors.red),
//                         SizedBox(width: 4),
//                         Text('Clear all', style: TextStyle(color: Colors.red)),
//                       ],
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//           // Invoices List
//           Expanded(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : _hasError
//                 ? _buildErrorState()
//                 : _filteredInvoices.isEmpty
//                 ? _buildEmptyState()
//                 : _buildInvoicesList(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   bool get _hasActiveFilters {
//     return _searchQuery.isNotEmpty ||
//         _selectedStatusFilter != 'all' ||
//         _selectedPaymentFilter != 'all' ||
//         _selectedCustomerFilter != null ||
//         _startDate != null ||
//         _endDate != null;
//   }
//
//   Widget _buildErrorState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.error_outline, size: 64, color: Colors.red),
//           SizedBox(height: 16),
//           Text(
//             'Failed to load invoices',
//             style: TextStyle(fontSize: 18, color: Colors.grey),
//           ),
//           SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: _loadAllData,
//             child: Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.receipt_long, size: 64, color: Colors.grey),
//           SizedBox(height: 16),
//           Text(
//             'No invoices found',
//             style: TextStyle(fontSize: 18, color: Colors.grey),
//           ),
//           SizedBox(height: 8),
//           Text(
//             _hasActiveFilters
//                 ? 'Try adjusting your search or filters'
//                 : 'No invoices have been created yet',
//             style: TextStyle(color: Colors.grey),
//             textAlign: TextAlign.center,
//           ),
//           SizedBox(height: 16),
//           if (_hasActiveFilters)
//             ElevatedButton(
//               onPressed: () {
//                 _searchController.clear();
//                 setState(() {
//                   _searchQuery = '';
//                   _selectedStatusFilter = 'all';
//                   _selectedPaymentFilter = 'all';
//                   _selectedCustomerFilter = null;
//                   _startDate = null;
//                   _endDate = null;
//                 });
//                 _applyFilters();
//               },
//               child: Text('Clear Filters'),
//             )
//           else
//             ElevatedButton(
//               onPressed: _loadAllData,
//               child: Text('Reload'),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInvoicesList() {
//     return RefreshIndicator(
//       onRefresh: _loadAllData,
//       child: ListView.builder(
//         itemCount: _filteredInvoices.length,
//         itemBuilder: (context, index) {
//           final invoice = _filteredInvoices[index];
//           return _buildInvoiceCard(invoice);
//         },
//       ),
//     );
//   }
// }
//
// extension StringExtension on String {
//   String toTitleCase() {
//     if (isEmpty) return this;
//     return split(' ').map((word) {
//       if (word.isEmpty) return word;
//       return word[0].toUpperCase() + word.substring(1).toLowerCase();
//     }).join(' ');
//   }
// }