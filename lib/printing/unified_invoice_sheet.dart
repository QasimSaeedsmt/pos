// // unified_invoice_sheet.dart
// import 'package:flutter/material.dart';
// import 'package:mpcm/printing/printing_setting_screen.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io';
//
// import '../app.dart';
// import '../constants.dart';
// import '../features/customerBase/customer_base.dart';
// import '../features/orderBase/order_base.dart';
// import 'invoice_model.dart';
// import 'invoice_service.dart';
//
// class UnifiedInvoiceSheet extends StatefulWidget {
//   final AppOrder order;
//   final Customer? customer;
//   final Map<String, dynamic>? enhancedData;
//   final bool isQuickMode;
//
//   const UnifiedInvoiceSheet({
//     super.key,
//     required this.order,
//     this.customer,
//     this.enhancedData,
//     this.isQuickMode = false,
//   });
//
//   @override
//   State<UnifiedInvoiceSheet> createState() => _UnifiedInvoiceSheetState();
// }
//
// class _UnifiedInvoiceSheetState extends State<UnifiedInvoiceSheet> {
//   final InvoiceService _invoiceService = InvoiceService();
//   String _selectedTemplate = 'traditional';
//   bool _autoPrint = false;
//   bool _autoShare = false;
//   bool _printAndShare = true;
//   bool _processing = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//   }
//
//   Future<void> _loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _selectedTemplate = prefs.getString('default_invoice_template') ?? 'traditional';
//       _autoPrint = prefs.getBool('auto_print') ?? false;
//       _autoShare = prefs.getBool('auto_share') ?? false;
//       _printAndShare = prefs.getBool('print_and_share') ?? true;
//     });
//   }
//
//   Future<Map<String, dynamic>> _getBusinessInfo() async {
//     final prefs = await SharedPreferences.getInstance();
//     return {
//       'name': prefs.getString('business_name') ?? 'Your Business Name',
//       'address': prefs.getString('business_address') ?? '',
//       'phone': prefs.getString('business_phone') ?? '',
//       'email': prefs.getString('business_email') ?? '',
//       'website': prefs.getString('business_website') ?? '',
//       'tagline': prefs.getString('business_tagline') ?? '',
//       'taxNumber': prefs.getString('business_tax_number') ?? '',
//     };
//   }
//
//   Future<Map<String, dynamic>> _getInvoiceSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     return {
//       'defaultTemplate': _selectedTemplate,
//       'taxRate': prefs.getDouble('tax_rate') ?? 0.0,
//       'discountRate': prefs.getDouble('discount_rate') ?? 0.0,
//       'autoPrint': _autoPrint,
//       'includeCustomerDetails': prefs.getBool('include_customer_details') ?? true,
//       'defaultNotes': prefs.getString('default_notes') ?? 'Thank you for your business!',
//     };
//   }
//
//   Future<void> _processInvoice({bool printOnly = false, bool shareOnly = false}) async {
//     setState(() => _processing = true);
//
//     try {
//       final businessInfo = await _getBusinessInfo();
//       final invoiceSettings = await _getInvoiceSettings();
//
//       final invoice = widget.enhancedData != null
//           ? Invoice.fromEnhancedOrder(
//         widget.order,
//         widget.customer,
//         businessInfo,
//         invoiceSettings,
//         templateType: _selectedTemplate,
//         enhancedData: widget.enhancedData!,
//       )
//           : Invoice.fromOrder(
//         widget.order,
//         widget.customer,
//         businessInfo,
//         invoiceSettings,
//         templateType: _selectedTemplate,
//       );
//
//       // Generate PDF first
//       final pdfFile = await _invoiceService.generatePdfInvoice(invoice);
//
//       // Determine actions based on parameters and settings
//       final shouldPrint = printOnly || (_printAndShare && !shareOnly) || _autoPrint;
//       final shouldShare = shareOnly || (_printAndShare && !printOnly) || _autoShare;
//
//       // Execute actions
//       if (shouldPrint) {
//         await _invoiceService.printInvoice(invoice);
//       }
//
//       if (shouldShare) {
//         await _invoiceService.shareInvoice(invoice);
//       }
//
//       // Show success feedback
//       if (!widget.isQuickMode) {
//         _showSuccessDialog(invoice, pdfFile);
//       } else {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Invoice processed successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => _processing = false);
//     }
//   }
//
//   void _showSuccessDialog(Invoice invoice, File pdfFile) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Row(
//           children: [
//             Icon(Icons.check_circle, color: Colors.green),
//             SizedBox(width: 8),
//             Text('Success!'),
//           ],
//         ),
//         content: Text('Invoice ${invoice.invoiceNumber} has been processed successfully.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _invoiceService.printInvoice(invoice);
//             },
//             child: Text('Print Again'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _invoiceService.shareInvoice(invoice);
//             },
//             child: Text('Share PDF'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _updateTemplate(String template) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('default_invoice_template', template);
//     setState(() => _selectedTemplate = template);
//   }
//
//   void _updateAutoPrint(bool value) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('auto_print', value);
//     setState(() => _autoPrint = value);
//   }
//
//   void _updateAutoShare(bool value) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('auto_share', value);
//     setState(() => _autoShare = value);
//   }
//
//   void _updatePrintAndShare(bool value) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('print_and_share', value);
//     setState(() => _printAndShare = value);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isEnhanced = widget.enhancedData != null;
//
//     return SafeArea(
//       child: Container(
//         padding: EdgeInsets.all(24),
//         decoration: BoxDecoration(
//           color: theme.colorScheme.surface,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _buildHeader(theme, isEnhanced),
//             SizedBox(height: 20),
//
//             _buildOrderSummary(theme),
//             SizedBox(height: 16),
//
//             if (!widget.isQuickMode) ..._buildDetailedControls(theme),
//             if (widget.isQuickMode) ..._buildQuickActions(theme),
//
//             if (_processing) ..._buildProcessingIndicator(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader(ThemeData theme, bool isEnhanced) {
//     return Row(
//       children: [
//         Icon(Icons.receipt_long, color: theme.colorScheme.primary, size: 28),
//         SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 widget.isQuickMode ? 'Order Complete!' : 'Invoice Options',
//                 style: theme.textTheme.titleLarge?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               if (isEnhanced)
//                 Text(
//                   'Enhanced pricing applied',
//                   style: theme.textTheme.bodySmall?.copyWith(
//                     color: Colors.green,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         if (!widget.isQuickMode)
//           IconButton(
//             icon: Icon(Icons.settings_outlined),
//             onPressed: _showSettings,
//             tooltip: 'Invoice Settings',
//           ),
//       ],
//     );
//   }
//
//   Widget _buildOrderSummary(ThemeData theme) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: theme.colorScheme.primary.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Order #${widget.order.number}',
//                 style: theme.textTheme.bodyLarge?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               Text(
//                 '${widget.order.lineItems.length} items',
//                 style: theme.textTheme.bodySmall,
//               ),
//             ],
//           ),
//           Spacer(),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 '${Constants.CURRENCY_NAME}${widget.order.total.toStringAsFixed(2)}',
//                 style: theme.textTheme.titleLarge?.copyWith(
//                   fontWeight: FontWeight.bold,
//                   color: theme.colorScheme.primary,
//                 ),
//               ),
//               if (widget.enhancedData != null && widget.enhancedData!['totalSavings'] != null)
//                 Text(
//                   'Saved ${Constants.CURRENCY_NAME}${(widget.enhancedData!['totalSavings'] ?? 0).toStringAsFixed(2)}',
//                   style: theme.textTheme.bodySmall?.copyWith(
//                     color: Colors.green,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   List<Widget> _buildQuickActions(ThemeData theme) {
//     return [
//       FilledButton(
//         onPressed: () => _processInvoice(),
//         style: FilledButton.styleFrom(
//           minimumSize: Size(double.infinity, 56),
//           backgroundColor: theme.colorScheme.primary,
//         ),
//         child: _processing
//             ? SizedBox(
//           width: 20,
//           height: 20,
//           child: CircularProgressIndicator(
//             strokeWidth: 2,
//             color: Colors.white,
//           ),
//         )
//             : Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.auto_awesome, size: 20),
//             SizedBox(width: 8),
//             Text(
//               'Print & Share Invoice',
//               style: theme.textTheme.titleMedium?.copyWith(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//       SizedBox(height: 12),
//       OutlinedButton(
//         onPressed: () => Navigator.pop(context),
//         style: OutlinedButton.styleFrom(
//           minimumSize: Size(double.infinity, 48),
//         ),
//         child: Text('Continue'),
//       ),
//     ];
//   }
//
//   List<Widget> _buildDetailedControls(ThemeData theme) {
//     return [
//       _buildTemplateSelector(theme),
//       SizedBox(height: 20),
//
//       _buildActionSettings(theme),
//       SizedBox(height: 20),
//
//       Row(
//         children: [
//           Expanded(
//             child: FilledButton.icon(
//               onPressed: _processing ? null : () => _processInvoice(printOnly: true),
//               icon: Icon(Icons.print),
//               label: Text('Print Only'),
//               style: FilledButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 padding: EdgeInsets.symmetric(vertical: 16),
//               ),
//             ),
//           ),
//           SizedBox(width: 12),
//           Expanded(
//             child: FilledButton.icon(
//               onPressed: _processing ? null : () => _processInvoice(shareOnly: true),
//               icon: Icon(Icons.share),
//               label: Text('Share Only'),
//               style: FilledButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 padding: EdgeInsets.symmetric(vertical: 16),
//               ),
//             ),
//           ),
//         ],
//       ),
//       SizedBox(height: 8),
//       SizedBox(
//         width: double.infinity,
//         child: FilledButton.icon(
//           onPressed: _processing ? null : () => _processInvoice(),
//           icon: Icon(Icons.rocket_launch),
//           label: Text('Print & Share'),
//           style: FilledButton.styleFrom(
//             padding: EdgeInsets.symmetric(vertical: 16),
//           ),
//         ),
//       ),
//       SizedBox(height: 8),
//       OutlinedButton(
//         onPressed: () => Navigator.pop(context),
//         style: OutlinedButton.styleFrom(
//           minimumSize: Size(double.infinity, 48),
//         ),
//         child: Text('Cancel'),
//       ),
//     ];
//   }
//
//   Widget _buildTemplateSelector(ThemeData theme) {
//     final templates = [
//       {'label': 'Traditional', 'value': 'traditional', 'icon': Icons.description},
//       {'label': 'Thermal', 'value': 'thermal', 'icon': Icons.receipt},
//       {'label': 'Modern', 'value': 'modern', 'icon': Icons.design_services},
//     ];
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Invoice Template',
//           style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
//         ),
//         SizedBox(height: 12),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: templates.map((template) {
//             final isSelected = _selectedTemplate == template['value'];
//             return FilterChip(
//               label: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(template['icon'] as IconData, size: 16),
//                   SizedBox(width: 4),
//                   Text(template['label'] as String),
//                 ],
//               ),
//               selected: isSelected,
//               onSelected: (selected) => _updateTemplate(template['value'] as String),
//               backgroundColor: isSelected
//                   ? theme.colorScheme.primary.withOpacity(0.1)
//                   : null,
//               labelStyle: TextStyle(
//                 color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
//               ),
//               checkmarkColor: theme.colorScheme.primary,
//             );
//           }).toList(),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildActionSettings(ThemeData theme) {
//     return Column(
//       children: [
//         SwitchListTile(
//           title: Text('Auto Print & Share'),
//           subtitle: Text('Automatically print and share after order completion'),
//           value: _printAndShare,
//           onChanged: _updatePrintAndShare,
//           secondary: Icon(Icons.auto_awesome),
//         ),
//         if (!_printAndShare) ...[
//           SwitchListTile(
//             title: Text('Auto Print'),
//             subtitle: Text('Automatically print after order completion'),
//             value: _autoPrint,
//             onChanged: _updateAutoPrint,
//             secondary: Icon(Icons.print),
//           ),
//           SwitchListTile(
//             title: Text('Auto Share'),
//             subtitle: Text('Automatically share PDF after order completion'),
//             value: _autoShare,
//             onChanged: _updateAutoShare,
//             secondary: Icon(Icons.share),
//           ),
//         ],
//       ],
//     );
//   }
//
//   List<Widget> _buildProcessingIndicator() {
//     return [
//       SizedBox(height: 16),
//       LinearProgressIndicator(),
//       SizedBox(height: 16),
//       Text(
//         'Processing invoice...',
//         style: TextStyle(color: Colors.grey[600]),
//         textAlign: TextAlign.center,
//       ),
//     ];
//   }
//
//   void _showSettings() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => InvoiceSettingsScreen()),
//     ).then((_) => _loadSettings());
//   }
// }