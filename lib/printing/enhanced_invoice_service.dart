// // enhanced_invoice_service.dart
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:path_provider/path_provider.dart';
//
// import '../features/customerBase/customer_base.dart';
// import '../features/orderBase/order_base.dart';
// import 'invoice_model.dart';
// import 'invoice_service.dart';
//
// class EnhancedInvoiceService {
//   static final EnhancedInvoiceService _instance = EnhancedInvoiceService._internal();
//   factory EnhancedInvoiceService() => _instance;
//   EnhancedInvoiceService._internal();
//
//   final InvoiceService _invoiceService = InvoiceService();
//
//   // Modern invoice processing with synchronization
//   Future<InvoiceProcessingResult> processInvoiceWithSync({
//     required AppOrder order,
//     required Customer? customer,
//     required Map<String, dynamic> businessInfo,
//     required Map<String, dynamic> invoiceSettings,
//     required Map<String, dynamic>? enhancedData,
//     required String templateType,
//     bool shouldPrint = true,
//     bool shouldShare = true,
//   }) async {
//     try {
//       // Create invoice
//       final invoice = enhancedData != null
//           ? Invoice.fromEnhancedOrder(
//         order,
//         customer,
//         businessInfo,
//         invoiceSettings,
//         templateType: templateType,
//         enhancedData: enhancedData,
//       )
//           : Invoice.fromOrder(
//         order,
//         customer,
//         businessInfo,
//         invoiceSettings,
//         templateType: templateType,
//       );
//
//       // Generate PDF
//       final pdfFile = await _invoiceService.generatePdfInvoice(invoice);
//
//       // Execute synchronized actions
//       final results = await _executeSynchronizedActions(
//         invoice: invoice,
//         pdfFile: pdfFile,
//         shouldPrint: shouldPrint,
//         shouldShare: shouldShare,
//       );
//
//       return InvoiceProcessingResult(
//         success: true,
//         invoice: invoice,
//         pdfFile: pdfFile,
//         printSuccess: results['printSuccess'],
//         shareSuccess: results['shareSuccess'],
//       );
//     } catch (e) {
//       return InvoiceProcessingResult(
//         success: false,
//         error: e.toString(),
//       );
//     }
//   }
//
//   Future<Map<String, bool>> _executeSynchronizedActions({
//     required Invoice invoice,
//     required File pdfFile,
//     required bool shouldPrint,
//     required bool shouldShare,
//   }) async {
//     bool printSuccess = false;
//     bool shareSuccess = false;
//
//     try {
//       // Execute printing first if requested
//       if (shouldPrint) {
//         try {
//           await _invoiceService.printInvoice(invoice);
//           printSuccess = true;
//         } catch (e) {
//           print('Printing failed: $e');
//           printSuccess = false;
//         }
//       }
//
//       // Then execute sharing
//       if (shouldShare) {
//         try {
//           await _invoiceService.shareInvoice(invoice);
//           shareSuccess = true;
//         } catch (e) {
//           print('Sharing failed: $e');
//           shareSuccess = false;
//         }
//       }
//
//       return {
//         'printSuccess': printSuccess,
//         'shareSuccess': shareSuccess,
//       };
//     } catch (e) {
//       return {
//         'printSuccess': false,
//         'shareSuccess': false,
//       };
//     }
//   }
//
//   // Smart template selection
//   Future<String> getSmartTemplate(AppOrder order) async {
//     final prefs = await SharedPreferences.getInstance();
//     final defaultTemplate = prefs.getString('default_invoice_template') ?? 'traditional';
//     final smartSelection = prefs.getBool('smart_template_selection') ?? true;
//
//     if (!smartSelection) {
//       return defaultTemplate;
//     }
//
//     // Smart logic based on order characteristics
//     if (order.total < 500) {
//       return 'thermal'; // Small orders -> thermal
//     } else if (order.lineItems.length > 8) {
//       return 'traditional'; // Many items -> traditional for better readability
//     } else if (order.total > 2000) {
//       return 'modern'; // Large orders -> modern template
//     } else {
//       return defaultTemplate;
//     }
//   }
//
//   // Batch processing for multiple orders
//   Future<List<InvoiceProcessingResult>> processBatchInvoices({
//     required List<AppOrder> orders,
//     required Map<String, dynamic> businessInfo,
//     required Map<String, dynamic> invoiceSettings,
//     bool shouldPrint = true,
//     bool shouldShare = true,
//   }) async {
//     final results = <InvoiceProcessingResult>[];
//
//     for (final order in orders) {
//       final result = await processInvoiceWithSync(
//         order: order,
//         customer: null,
//         businessInfo: businessInfo,
//         invoiceSettings: invoiceSettings,
//         enhancedData: null,
//         templateType: await getSmartTemplate(order),
//         shouldPrint: shouldPrint,
//         shouldShare: shouldShare,
//       );
//       results.add(result);
//
//       // Small delay to prevent overwhelming the system
//       await Future.delayed(Duration(milliseconds: 500));
//     }
//
//     return results;
//   }
//
//   // Get default settings
//   Future<Map<String, dynamic>> getDefaultSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     return {
//       'autoPrint': prefs.getBool('auto_print') ?? false,
//       'autoShare': prefs.getBool('auto_share') ?? false,
//       'printAndShare': prefs.getBool('print_and_share') ?? true,
//       'smartTemplateSelection': prefs.getBool('smart_template_selection') ?? true,
//       'defaultTemplate': prefs.getString('default_invoice_template') ?? 'traditional',
//     };
//   }
//
//   // Save settings
//   Future<void> saveSettings(Map<String, dynamic> settings) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('auto_print', settings['autoPrint'] ?? false);
//     await prefs.setBool('auto_share', settings['autoShare'] ?? false);
//     await prefs.setBool('print_and_share', settings['printAndShare'] ?? true);
//     await prefs.setBool('smart_template_selection', settings['smartTemplateSelection'] ?? true);
//     await prefs.setString('default_invoice_template', settings['defaultTemplate'] ?? 'traditional');
//   }
// }
//
// class InvoiceProcessingResult {
//   final bool success;
//   final Invoice? invoice;
//   final File? pdfFile;
//   final bool? printSuccess;
//   final bool? shareSuccess;
//   final String? error;
//
//   InvoiceProcessingResult({
//     required this.success,
//     this.invoice,
//     this.pdfFile,
//     this.printSuccess,
//     this.shareSuccess,
//     this.error,
//   });
// }