import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../features/customerBase/customer_base.dart';
import '../features/invoiceBase/invoice_and_printing_base.dart';
import '../features/users/users_base.dart';
import 'invoice_model.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../features/customerBase/customer_base.dart';
import '../features/invoiceBase/invoice_and_printing_base.dart';
import 'invoice_model.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../features/customerBase/customer_base.dart';
import '../features/invoiceBase/invoice_and_printing_base.dart';
import 'invoice_model.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../features/customerBase/customer_base.dart';
import '../features/invoiceBase/invoice_and_printing_base.dart';
import 'invoice_model.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../features/customerBase/customer_base.dart';
import '../features/invoiceBase/invoice_and_printing_base.dart';
import 'invoice_model.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../features/customerBase/customer_base.dart';
import '../features/invoiceBase/invoice_and_printing_base.dart';
import 'invoice_model.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  // Updated method to accept currentUser
  Future<File> generatePdfInvoice(Invoice invoice, {AppUser? currentUser}) async {
    try {
      final pdf = pw.Document();

      if (invoice.templateType == 'thermal') {
        _buildThermalInvoice(pdf, invoice, currentUser: currentUser);
      } else {
        _buildTraditionalInvoice(pdf, invoice, currentUser: currentUser);
      }

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${invoice.invoiceNumber}.pdf');
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      print('Error generating PDF: $e');
      rethrow;
    }
  }

  // Updated thermal invoice with user attribution
  void _buildThermalInvoice(pw.Document pdf, Invoice invoice, {AppUser? currentUser}) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _buildProfessionalThermalHeader(invoice, currentUser: currentUser),
                pw.SizedBox(height: 8),
                _buildThermalInvoiceDetails(invoice, currentUser: currentUser),
                pw.SizedBox(height: 8),

                // Credit Notice Section
                if (invoice.showCreditDetails)
                  _buildCreditNoticeSection(invoice),

                if (invoice.showCustomerDetails && invoice.customer != null)
                  _buildCompactCustomerInfo(invoice.customer!),
                if (invoice.showCustomerDetails && invoice.customer != null)
                  pw.SizedBox(height: 8),
                _buildProfessionalItemsTable(invoice),
                pw.SizedBox(height: 8),
                _buildEnhancedThermalTotals(invoice),
                pw.SizedBox(height: 8),

                // Credit Details Section
                if (invoice.showCreditDetails)
                  _buildCreditDetailsSection(invoice),

                _buildPaymentAndFooter(invoice, currentUser: currentUser),
                pw.SizedBox(height: 8),
                _buildCompactQRCode(invoice),
                pw.SizedBox(height: 8),
                _buildThankYouFooter(invoice, currentUser: currentUser),
              ],
            ),
          );
        },
      ),
    );
  }

  // Updated thermal header with user attribution
  pw.Widget _buildProfessionalThermalHeader(Invoice invoice, {AppUser? currentUser}) {
    final business = invoice.businessInfo;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: double.infinity,
          child: pw.Text(
            business['name']?.toString().toUpperCase() ?? 'YOUR BUSINESS',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (business['tagline'] != null)
          pw.Text(
            business['tagline']!,
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),

        // ADDED: User attribution line for thermal receipts
        if (currentUser != null)
          pw.Container(
            width: double.infinity,
            margin: pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Processed by: ${currentUser.formattedName}',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (business['phone'] != null)
              pw.Text(
                'Tel: ${business['phone']!}',
                style: pw.TextStyle(fontSize: 7),
              ),
            if (business['phone'] != null && business['email'] != null)
              pw.Text(' • ', style: pw.TextStyle(fontSize: 7)),
            if (business['email'] != null)
              pw.Text(
                'Email: ${business['email']!}',
                style: pw.TextStyle(fontSize: 7),
              ),
          ],
        ),
        if (business['address'] != null)
          pw.Text(
            business['address']!,
            style: pw.TextStyle(fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
        pw.Container(
          width: double.infinity,
          height: 1,
          margin: pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 1, color: PdfColors.black),
            ),
          ),
        ),
      ],
    );
  }

  // Updated thermal invoice details with user attribution
  pw.Widget _buildThermalInvoiceDetails(Invoice invoice, {AppUser? currentUser}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INVOICE',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
        ),
        pw.Text(
          '#${invoice.invoiceNumber}',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        pw.Text(
          'Date: ${DateFormat('dd/MM/yyyy').format(invoice.issueDate)}',
          style: pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          'Time: ${DateFormat('HH:mm').format(invoice.issueDate)}',
          style: pw.TextStyle(fontSize: 8),
        ),

        // ADDED: Staff information in invoice details section
        if (currentUser != null)
          pw.Text(
            'Staff: ${currentUser.formattedName}',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),

        if (invoice.orderId.isNotEmpty)
          pw.Text(
            'Order: ${invoice.orderId}',
            style: pw.TextStyle(fontSize: 8),
          ),
      ],
    );
  }

  // Updated payment section with user attribution
  pw.Widget _buildPaymentAndFooter(Invoice invoice, {AppUser? currentUser}) {
    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 0.5, color: PdfColors.black),
              bottom: pw.BorderSide(width: 0.5, color: PdfColors.black),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Payment Method:',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    invoice.paymentMethod.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // ADDED: Staff initials or name in payment section
              if (currentUser != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Handled by:',
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      _getUserInitials(currentUser.formattedName),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Updated thank you footer with user attribution
  pw.Widget _buildThankYouFooter(Invoice invoice, {AppUser? currentUser}) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.black),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            invoice.notes.isNotEmpty ? invoice.notes : "Thank you for your Business",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          // ADDED: Final user attribution in footer
          if (currentUser != null)
            pw.Container(
              margin: pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Served by: ${currentUser.formattedName}',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // Updated traditional invoice with user attribution
  void _buildTraditionalInvoice(pw.Document pdf, Invoice invoice, {AppUser? currentUser}) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildTraditionalHeader(invoice, currentUser: currentUser),
              pw.SizedBox(height: 20),

              if (invoice.showCreditDetails)
                _buildTraditionalCreditNotice(invoice),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInvoiceDetails(invoice, currentUser: currentUser),
                  pw.SizedBox(width: 50),
                  if (invoice.showCustomerDetails && invoice.customer != null)
                    _buildCustomerDetails(invoice.customer!),
                ],
              ),
              pw.SizedBox(height: 20),
              _buildTraditionalItemsTable(invoice),
              pw.SizedBox(height: 20),

              if (invoice.showCreditDetails)
                _buildTraditionalCreditDetails(invoice),

              _buildEnhancedTraditionalTotals(invoice),
              pw.SizedBox(height: 20),
              pw.Center(
                child: _buildTraditionalQRCode(invoice),
              ),
              pw.SizedBox(height: 20),
              _buildTraditionalFooter(invoice, currentUser: currentUser),
            ],
          );
        },
      ),
    );
  }

  // Updated traditional header with professional user attribution
  pw.Widget _buildTraditionalHeader(Invoice invoice, {AppUser? currentUser}) {
    final business = invoice.businessInfo;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  business['name']?.toString() ?? 'Your Business Name',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                if (business['tagline'] != null)
                  pw.Text(
                    business['tagline']!,
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),

                // ADDED: Professional user attribution in traditional header
                if (currentUser != null)
                  pw.Container(
                    margin: pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      'Invoice prepared by: ${currentUser.formattedName}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  width: 80,
                  height: 80,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  child: pw.Center(
                    child: pw.Text('LOGO', style: pw.TextStyle(fontSize: 10)),
                  ),
                ),

                // ADDED: User role/position in traditional header
                if (currentUser != null)
                  pw.Container(
                    margin: pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                      _getUserRoleDisplay(currentUser.role),
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Updated traditional invoice details with user attribution
  pw.Widget _buildInvoiceDetails(Invoice invoice, {AppUser? currentUser}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Text('Invoice No:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 10),
            pw.Text(invoice.invoiceNumber),
          ],
        ),
        pw.Row(
          children: [
            pw.Text('Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 10),
            pw.Text(DateFormat('MMMM dd, yyyy').format(invoice.issueDate)),
          ],
        ),

        // ADDED: Staff information in traditional invoice details
        if (currentUser != null)
          pw.Row(
            children: [
              pw.Text('Processed by:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              pw.Text(currentUser.formattedName),
            ],
          ),

        if (invoice.dueDate != null)
          pw.Row(
            children: [
              pw.Text('Due Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              pw.Text(DateFormat('MMMM dd, yyyy').format(invoice.dueDate!)),
            ],
          ),
      ],
    );
  }

  // Updated traditional footer with user attribution
  pw.Widget _buildTraditionalFooter(Invoice invoice, {AppUser? currentUser}) {
    final business = invoice.businessInfo;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),

        // ADDED: Professional attribution in footer
        if (currentUser != null)
          pw.Container(
            width: double.infinity,
            margin: pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Processed by:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  currentUser.formattedName,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        pw.Text(invoice.notes, style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            if (business['phone'] != null)
              pw.Column(
                children: [
                  pw.Text('Contact', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(business['phone']!),
                ],
              ),
            if (business['email'] != null)
              pw.Column(
                children: [
                  pw.Text('Email', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(business['email']!),
                ],
              ),
            if (business['website'] != null)
              pw.Column(
                children: [
                  pw.Text('Website', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(business['website']!),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('Thank you for your business!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // Helper methods for user attribution
  String _getUserInitials(String fullName) {
    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (fullName.isNotEmpty) {
      return fullName.substring(0, 1).toUpperCase();
    }
    return 'U'; // Default for Unknown
  }

  String _getUserRoleDisplay(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.clientAdmin:
        return 'Administrator';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.salesInventoryManager:
        return 'Sales Manager';
      default:
        return 'Staff';
    }
  }

  // Update other methods to accept currentUser parameter
  Future<void> printInvoice(Invoice invoice, {String? printer, AppUser? currentUser}) async {
    // Pass currentUser to generatePdfInvoice
    final pdfFile = await generatePdfInvoice(invoice, currentUser: currentUser);

    if (printer != null) {
      await _printToSpecificPrinter(invoice, printer);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await pdfFile.readAsBytes();
        },
      );
    }
  }

  pw.Widget _buildCreditNoticeSection(Invoice invoice) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange[50],
        border: pw.Border.all(color: PdfColors.orange, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'CREDIT SALE',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange[800],
            ),
          ),
          if (invoice.hasPartialPayment)
            pw.Text(
              'Partial Payment Received',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.orange[700],
              ),
            ),
        ],
      ),
    );
  }


  pw.Widget _buildCompactCustomerInfo(Customer customer) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CUSTOMER DETAILS',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(customer.fullName, style: pw.TextStyle(fontSize: 8)),
          if (customer.phone.isNotEmpty)
            pw.Text('Tel: ${customer.phone}', style: pw.TextStyle(fontSize: 7)),
          if (customer.email.isNotEmpty)
            pw.Text('Email: ${customer.email}', style: pw.TextStyle(fontSize: 7)),
        ],
      ),
    );
  }

  pw.Widget _buildProfessionalItemsTable(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.3),
      columnWidths: {
        0: pw.FlexColumnWidth(3.5),
        1: pw.FlexColumnWidth(1.0),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text('QTY', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text('PRICE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        ...invoice.items.map((item) => pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.name,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                  if (item.description.isNotEmpty)
                    pw.Text(
                      item.description,
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                    ),
                  if (invoice.hasEnhancedPricing && item.hasManualDiscount)
                    pw.Container(
                      margin: pw.EdgeInsets.only(top: 1),
                      child: pw.Text(
                        'Disc: ${item.manualDiscountPercent?.toStringAsFixed(1) ?? '0'}%',
                        style: pw.TextStyle(fontSize: 6, color: PdfColors.red),
                      ),
                    ),
                ],
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text(
                item.quantity.toString(),
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text(
                '${Constants.CURRENCY_NAME}${item.unitPrice.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: pw.Text(
                '${Constants.CURRENCY_NAME}${item.total.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildEnhancedThermalTotals(Invoice invoice) {
    final bool hasEnhanced = invoice.hasEnhancedPricing;
    final allDiscounts = invoice.allDiscounts;

    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        children: [
          _buildTotalLine('Subtotal', invoice.subtotal),

          if (hasEnhanced)
            ..._buildIndependentDiscounts(invoice, allDiscounts)
          else
            if (invoice.discountAmount > 0)
              _buildDiscountLine('Discount', invoice.discountAmount),

          if (hasEnhanced)
            _buildTotalLine('Net Amount', invoice.netAmount, isEmphasized: true),

          if (invoice.taxAmount > 0)
            _buildTotalLine('Tax', invoice.taxAmount),

          if (hasEnhanced && invoice.showShipping && invoice.shippingAmount > 0)
            _buildTotalLine('Shipping', invoice.shippingAmount),

          if (hasEnhanced && invoice.showTip && invoice.tipAmount > 0)
            _buildTotalLine('Tip', invoice.tipAmount),

          pw.Container(
            width: double.infinity,
            margin: pw.EdgeInsets.symmetric(vertical: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 0.5, color: PdfColors.black),
                bottom: pw.BorderSide(width: 0.5, color: PdfColors.black),
              ),
            ),
            height: 2,
          ),

          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  invoice.showCreditDetails && invoice.hasPartialPayment
                      ? 'AMOUNT DUE:'
                      : invoice.showCreditDetails
                      ? 'CREDIT AMOUNT:'
                      : 'TOTAL AMOUNT:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.Text(
                  invoice.showCreditDetails && invoice.hasPartialPayment
                      ? '${Constants.CURRENCY_NAME}${invoice.totalAmount.toStringAsFixed(2)}'
                      : invoice.showCreditDetails
                      ? '${Constants.CURRENCY_NAME}${invoice.creditAmount!.toStringAsFixed(2)}'
                      : '${Constants.CURRENCY_NAME}${invoice.totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          if (invoice.totalSavings > 0)
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(4),
              margin: pw.EdgeInsets.only(top: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.green, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL SAVINGS:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                      pw.Text(
                        '-${Constants.CURRENCY_NAME}${invoice.totalSavings.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                  if (invoice.taxAmount > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Tax Included:',
                          style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          '${Constants.CURRENCY_NAME}${invoice.taxAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildIndependentDiscounts(Invoice invoice, Map<String, double> discounts) {
    final List<pw.Widget> widgets = [];

    if (discounts['item_discounts'] != null && discounts['item_discounts']! > 0) {
      widgets.add(_buildDiscountLine('Item Discounts', discounts['item_discounts']!));
    }

    if (discounts['cart_discount'] != null && discounts['cart_discount']! > 0) {
      widgets.add(_buildDiscountLine('Cart Discount', discounts['cart_discount']!));
    }

    if (discounts['additional_discount'] != null && discounts['additional_discount']! > 0) {
      widgets.add(_buildDiscountLine('Additional Discount', discounts['additional_discount']!));
    }

    if (discounts['settings_discount'] != null && discounts['settings_discount']! > 0) {
      widgets.add(_buildDiscountLine('Standard Discount', discounts['settings_discount']!));
    }

    return widgets;
  }

  pw.Widget _buildTotalLine(String label, double amount, {bool isEmphasized = false}) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isEmphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isEmphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDiscountLine(String label, double amount) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.red,
            ),
          ),
          pw.Text(
            '-${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.red,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCreditDetailsSection(Invoice invoice) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CREDIT TERMS',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),

          if (invoice.hasPartialPayment)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Amount Paid:', style: pw.TextStyle(fontSize: 8)),
                pw.Text(
                  '${Constants.CURRENCY_NAME}${invoice.paidAmount!.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Credit Amount:', style: pw.TextStyle(fontSize: 8)),
              pw.Text(
                '${Constants.CURRENCY_NAME}${invoice.creditAmount!.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),

          if (invoice.creditDueDate != null)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Due Date:', style: pw.TextStyle(fontSize: 8)),
                pw.Text(
                  DateFormat('dd/MM/yyyy').format(invoice.creditDueDate!),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: invoice.isOverdueCredit ? PdfColors.red : PdfColors.black,
                  ),
                ),
              ],
            ),

          if (invoice.previousBalance != null && invoice.newBalance != null)
            pw.Column(
              children: [
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  height: 0.5,
                  color: PdfColors.grey,
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Previous Balance:', style: pw.TextStyle(fontSize: 7)),
                    pw.Text(
                      '${Constants.CURRENCY_NAME}${invoice.previousBalance!.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('New Balance:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '${Constants.CURRENCY_NAME}${invoice.newBalance!.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),

          if (invoice.isOverdueCredit)
            pw.Container(
              width: double.infinity,
              margin: pw.EdgeInsets.only(top: 4),
              padding: pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                color: PdfColors.red[50],
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Text(
                'OVERDUE - Please settle immediately',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.red,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }


  pw.Widget _buildCompactQRCode(Invoice invoice) {
    final qrData = _generateQRData(invoice);
    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        children: [
          pw.Text(
            'ORDER REFERENCE',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: 60,
            height: 60,
          ),
          pw.SizedBox(height: 4),
          // pw.Text(
          //   'Scan for order details',
          //   style: pw.TextStyle(fontSize: 6),
          // ),
          // pw.Text(
          //   '& returns',
          //   style: pw.TextStyle(fontSize: 6),
          // ),
          // pw.SizedBox(height: 2),
          // pw.Text(
          //   'Ref: ${invoice.invoiceNumber}',
          //   style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
          // ),
        ],
      ),
    );
  }

  String _generateQRData(Invoice invoice) {
    final businessName = invoice.businessInfo['name'] ?? 'Your Business';
    final customerName = invoice.customer?.fullName ?? 'Walk-in Customer';

    return jsonEncode({
      'type': 'invoice_reference',
      'invoice_number': invoice.invoiceNumber,
      'order_id': invoice.orderId,
      'date': DateFormat('yyyy-MM-dd').format(invoice.issueDate),
      'total': invoice.totalAmount,
      'currency': Constants.CURRENCY_NAME,
      'business': businessName,
      'customer': customerName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }


  pw.Widget _buildTraditionalCreditNotice(Invoice invoice) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange[50],
        border: pw.Border.all(color: PdfColors.orange, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            '⚠️',
            style: pw.TextStyle(fontSize: 16),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CREDIT SALE INVOICE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange[800],
                  ),
                ),
                if (invoice.hasPartialPayment)
                  pw.Text(
                    'Partial payment received. Balance on credit.',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.orange[700],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerDetails(Customer customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('BILL TO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text(customer.fullName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (customer.company?.isNotEmpty == true) pw.Text(customer.company!),
        if (customer.email.isNotEmpty) pw.Text(customer.email),
        if (customer.phone.isNotEmpty) pw.Text(customer.phone),
        if (customer.address1?.isNotEmpty == true) pw.Text(customer.address1!),
        if (customer.city?.isNotEmpty == true && customer.postcode?.isNotEmpty == true)
          pw.Text('${customer.city!}, ${customer.postcode!}'),
      ],
    );
  }

  pw.Widget _buildTraditionalItemsTable(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ],
        ),
        ...invoice.items.map((item) => pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  if (item.description.isNotEmpty)
                    pw.Text(item.description, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  if (invoice.hasEnhancedPricing && item.hasManualDiscount)
                    pw.Container(
                      margin: pw.EdgeInsets.only(top: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Discount: -${Constants.CURRENCY_NAME}${item.discountAmount?.toStringAsFixed(2) ?? '0.00'} (${item.manualDiscountPercent?.toStringAsFixed(1) ?? '0'}%)',
                            style: pw.TextStyle(fontSize: 9, color: PdfColors.red),
                          ),
                          pw.Text(
                            'Original: ${Constants.CURRENCY_NAME}${item.baseSubtotal?.toStringAsFixed(2) ?? (item.unitPrice * item.quantity).toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(item.quantity.toString())),
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${Constants.CURRENCY_NAME}${item.unitPrice.toStringAsFixed(2)}')),
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('${Constants.CURRENCY_NAME}${item.total.toStringAsFixed(2)}')),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildTraditionalCreditDetails(Invoice invoice) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Credit Sale Details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Table(
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              if (invoice.hasPartialPayment)
                _buildTraditionalCreditDetailRow(
                  'Amount Paid',
                  invoice.paidAmount!,
                  isEmphasized: false,
                ),
              _buildTraditionalCreditDetailRow(
                'Credit Amount',
                invoice.creditAmount!,
                isEmphasized: false,
              ),
              if (invoice.creditDueDate != null)
                _buildTraditionalCreditDetailRow(
                  'Due Date',
                  0,
                  textValue: DateFormat('MMMM dd, yyyy').format(invoice.creditDueDate!),
                  isOverdue: invoice.isOverdueCredit,
                  isEmphasized: false,
                ),
              if (invoice.previousBalance != null)
                _buildTraditionalCreditDetailRow(
                  'Previous Balance',
                  invoice.previousBalance!,
                  isEmphasized: false,
                ),
              if (invoice.newBalance != null)
                _buildTraditionalCreditDetailRow(
                  'New Balance',
                  invoice.newBalance!,
                  isEmphasized: true,
                ),
            ],
          ),

          if (invoice.isOverdueCredit)
            pw.Container(
              width: double.infinity,
              margin: pw.EdgeInsets.only(top: 12),
              padding: pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.red[50],
                border: pw.Border.all(color: PdfColors.red),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'OVERDUE - This invoice is past due. Please settle immediately to avoid additional charges.',
                style: pw.TextStyle(
                  color: PdfColors.red,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // CORRECTED METHOD - Properly defined parameters
  pw.TableRow _buildTraditionalCreditDetailRow(
      String label,
      double amount, {
        String? textValue,
        bool isEmphasized = false,
        bool isOverdue = false,
      }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isEmphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            textValue ?? '${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: isEmphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isOverdue ? PdfColors.red : PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildEnhancedTraditionalTotals(Invoice invoice) {
    final bool hasEnhanced = invoice.hasEnhancedPricing;
    final allDiscounts = invoice.allDiscounts;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 300,
                child: pw.Column(
                  children: [
                    _enhancedTotalRow('Gross Amount', invoice.subtotal, isHeader: true),

                    if (hasEnhanced)
                      ..._buildEnhancedDiscountBreakdown(invoice, allDiscounts)
                    else
                      if (invoice.discountAmount > 0)
                        _enhancedTotalRow('Discount', -invoice.discountAmount, isDiscount: true),

                    if (hasEnhanced)
                      _enhancedTotalRow('NET AMOUNT', invoice.netAmount, isNetAmount: true),

                    if (invoice.taxAmount > 0)
                      _enhancedTotalRow('Tax', invoice.taxAmount),

                    if (hasEnhanced && invoice.showShipping)
                      _enhancedTotalRow('Shipping', invoice.shippingAmount),

                    if (hasEnhanced && invoice.showTip)
                      _enhancedTotalRow('Tip', invoice.tipAmount),

                    pw.Divider(thickness: 2),

                    // Credit-specific total display
                    if (invoice.showCreditDetails && invoice.hasPartialPayment)
                      _enhancedTotalRow('AMOUNT DUE', invoice.totalAmount, isTotal: true)
                    else if (invoice.showCreditDetails)
                      _enhancedTotalRow('CREDIT AMOUNT', invoice.creditAmount!, isTotal: true)
                    else
                      _enhancedTotalRow('FINAL TOTAL', invoice.totalAmount, isTotal: true),

                    if (invoice.totalSavings > 0 || invoice.taxAmount > 0)
                      pw.Container(
                        margin: pw.EdgeInsets.only(top: 8),
                        padding: pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.green),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          children: [
                            if (invoice.totalSavings > 0)
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('TOTAL SAVINGS:',
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                                  pw.Text('-${Constants.CURRENCY_NAME}${invoice.totalSavings.toStringAsFixed(2)}',
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                                ],
                              ),

                            if (invoice.taxAmount > 0)
                              pw.Padding(
                                padding: pw.EdgeInsets.only(top: 8),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Tax Applied:',
                                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                    pw.Text('${Constants.CURRENCY_NAME}${invoice.taxAmount.toStringAsFixed(2)}',
                                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                  ],
                                ),
                              ),

                            if (hasEnhanced && allDiscounts.isNotEmpty)
                              pw.Container(
                                margin: pw.EdgeInsets.only(top: 8),
                                child: pw.Column(
                                  children: allDiscounts.entries
                                      .where((entry) => entry.value > 0)
                                      .map((entry) => pw.Padding(
                                    padding: pw.EdgeInsets.symmetric(vertical: 2),
                                    child: pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text(
                                          _getDiscountLabel(entry.key).replaceAll('  • ', ''),
                                          style: pw.TextStyle(fontSize: 9, color: PdfColors.green),
                                        ),
                                        pw.Text(
                                          '-${Constants.CURRENCY_NAME}${entry.value.toStringAsFixed(2)}',
                                          style: pw.TextStyle(fontSize: 9, color: PdfColors.green),
                                        ),
                                      ],
                                    ),
                                  ))
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Payment Method: ${invoice.paymentMethod}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  List<pw.Widget> _buildEnhancedDiscountBreakdown(Invoice invoice, Map<String, double> discounts) {
    final List<pw.Widget> widgets = [];

    if (discounts['item_discounts'] != null && discounts['item_discounts']! > 0) {
      widgets.add(_enhancedTotalRow('Item Discounts', -discounts['item_discounts']!, isDiscount: true));
    }

    if (discounts['cart_discount'] != null && discounts['cart_discount']! > 0) {
      widgets.add(_enhancedTotalRow('Cart Discount', -discounts['cart_discount']!, isDiscount: true));
    }

    if (discounts['additional_discount'] != null && discounts['additional_discount']! > 0) {
      widgets.add(_enhancedTotalRow('Additional Discount', -discounts['additional_discount']!, isDiscount: true));
    }

    if (discounts['settings_discount'] != null && discounts['settings_discount']! > 0) {
      widgets.add(_enhancedTotalRow('Standard Discount', -discounts['settings_discount']!, isDiscount: true));
    }

    return widgets;
  }

  String _getDiscountLabel(String discountType) {
    switch (discountType) {
      case 'item_discounts':
        return 'Item Discounts';
      case 'cart_discount':
        return 'Cart Discount';
      case 'additional_discount':
        return 'Additional Discount';
      case 'settings_discount':
        return 'Standard Discount';
      case 'legacy_discount':
        return 'Discount';
      default:
        return discountType.replaceAll('_', ' ');
    }
  }

  pw.Widget _enhancedTotalRow(String label, double amount, {
    bool isTotal = false,
    bool isDiscount = false,
    bool isNetAmount = false,
    bool isHeader = false,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: isHeader ? 6 : 4),
      decoration: isHeader ? pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400))
      ) : null,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal || isNetAmount ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 12 : (isNetAmount ? 11 : 10),
              color: isDiscount ? PdfColors.red : (isNetAmount ? PdfColors.blue : PdfColors.black),
            ),
          ),
          pw.Text(
            '${isDiscount && amount > 0 ? '-' : ''}${Constants.CURRENCY_NAME}${amount.abs().toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: isTotal || isNetAmount ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 12 : (isNetAmount ? 11 : 10),
              color: isDiscount ? PdfColors.red : (isNetAmount ? PdfColors.blue : PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTraditionalQRCode(Invoice invoice) {
    final qrData = _generateQRData(invoice);

    return pw.Center(
      child: pw.Container(
        constraints: pw.BoxConstraints(
          maxWidth: 250,
        ),
        padding: pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'ORDER REFERENCE',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Container(
              color: PdfColors.white,
              padding: pw.EdgeInsets.all(10),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 100,
                height: 100,
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'Scan for order details & returns',
              style: pw.TextStyle(
                fontSize: 11,
                fontStyle: pw.FontStyle.italic,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Ref: ${invoice.invoiceNumber}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _printToSpecificPrinter(Invoice invoice, String printerName) async {
    // Implement specific printer logic here
    // This depends on your printing plugin capabilities
    print('Printing to: $printerName');
    await printInvoice(invoice); // Fallback to default for now
  }
  Future<void> shareInvoice(Invoice invoice) async {
    final pdfFile = await generatePdfInvoice(invoice);
    await Share.shareXFiles([XFile(pdfFile.path)], text: 'Invoice ${invoice.invoiceNumber}');
  }

  Future<void> printDirect(Invoice invoice) async {
    if (invoice.templateType == 'thermal') {
      await _printThermalInvoice(invoice);
    } else {
      await _printTraditionalInvoice(invoice);
    }
  }

  Future<void> _printThermalInvoice(Invoice invoice) async {
    print('Printing thermal invoice: ${invoice.invoiceNumber}');
    if (invoice.hasEnhancedPricing) {
      await _printEnhancedThermalInvoice(invoice);
    } else {
      await _printBasicThermalInvoice(invoice);
    }
  }

  Future<void> _printTraditionalInvoice(Invoice invoice) async {
    print('Printing traditional invoice: ${invoice.invoiceNumber}');
    if (invoice.hasEnhancedPricing) {
      await _printEnhancedTraditionalInvoice(invoice);
    } else {
      await _printBasicTraditionalInvoice(invoice);
    }
  }

  Future<void> _printEnhancedThermalInvoice(Invoice invoice) async {
    print('Enhanced thermal invoice with credit support: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }

  Future<void> _printBasicThermalInvoice(Invoice invoice) async {
    print('Basic thermal invoice: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }

  Future<void> _printEnhancedTraditionalInvoice(Invoice invoice) async {
    print('Enhanced traditional invoice with credit details: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }

  Future<void> _printBasicTraditionalInvoice(Invoice invoice) async {
    print('Basic traditional invoice: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }
}



















extension on PdfColor {
  PdfColor? operator [](int other) {}
}

class OrderQRData {
  final String invoiceId;
  final String orderId;
  final String invoiceNumber;
  final DateTime issueDate;
  final double totalAmount;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String status;
  final List<QRLineItem> lineItems;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final String paymentMethod;
  final String businessName;
  final String businessPhone;
  final String businessEmail;
  final bool isCreditSale;
  final double? creditAmount;
  final double? paidAmount;
  final DateTime? creditDueDate;
  final String? returnPolicy;
  final String? warrantyInfo;
  final String verificationCode;

  OrderQRData({
    required this.invoiceId,
    required this.orderId,
    required this.invoiceNumber,
    required this.issueDate,
    required this.totalAmount,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.status,
    required this.lineItems,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.paymentMethod,
    required this.businessName,
    required this.businessPhone,
    required this.businessEmail,
    this.isCreditSale = false,
    this.creditAmount,
    this.paidAmount,
    this.creditDueDate,
    this.returnPolicy,
    this.warrantyInfo,
    required this.verificationCode,
  });
  static String generateVerificationCode(String invoiceNumber) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return '${invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}-${timestamp.toString().substring(8)}-${random.toString().padLeft(4, '0')}';
  }

  // ✅ Fixed fromInvoice factory
  factory OrderQRData.fromInvoice(Invoice invoice) {
    // Use the static method correctly
    final verificationCode = OrderQRData.generateVerificationCode(invoice.invoiceNumber);

    // Extract line items for QR data
    final lineItems = invoice.items.map((item) {
      return QRLineItem(
        productName: item.name,
        productSku: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.total,
        hasDiscount: item.hasManualDiscount,
        discountAmount: item.discountAmount ?? 0.0,
        discountPercent: item.manualDiscountPercent ?? 0.0,
      );
    }).toList();

    return OrderQRData(
      invoiceId: invoice.id,
      orderId: invoice.orderId,
      invoiceNumber: invoice.invoiceNumber,
      issueDate: invoice.issueDate,
      totalAmount: invoice.totalAmount,
      customerId: invoice.customer?.id,
      customerName: invoice.customer?.fullName,
      customerPhone: invoice.customer?.phone,
      customerEmail: invoice.customer?.email,
      status: invoice.status,
      lineItems: lineItems,
      subtotal: invoice.subtotal,
      taxAmount: invoice.taxAmount,
      discountAmount: invoice.discountAmount,
      paymentMethod: invoice.paymentMethod,
      businessName: invoice.businessInfo['name']?.toString() ?? 'Your Business',
      businessPhone: invoice.businessInfo['phone']?.toString() ?? '',
      businessEmail: invoice.businessInfo['email']?.toString() ?? '',
      isCreditSale: invoice.isCreditSale,
      creditAmount: invoice.creditAmount,
      paidAmount: invoice.paidAmount,
      creditDueDate: invoice.creditDueDate,
      returnPolicy: invoice.businessInfo['returnPolicy']?.toString(),
      warrantyInfo: invoice.businessInfo['warrantyInfo']?.toString(),
      verificationCode: verificationCode,
    );
  }

  // ✅ Fixed fromJson factory
  factory OrderQRData.fromJson(Map<String, dynamic> json) {
    // Declare lineItems first
    final lineItems = (json['lineItems'] as List).map((item) {
      return QRLineItem.fromJson(item);
    }).toList();

    final customer = json['customer'] as Map<String, dynamic>;
    final financials = json['financials'] as Map<String, dynamic>;
    final business = json['business'] as Map<String, dynamic>;
    final creditInfo = json['creditInfo'] as Map<String, dynamic>?;
    final policies = json['policies'] as Map<String, dynamic>;
    final verification = json['verification'] as Map<String, dynamic>;

    return OrderQRData(
      invoiceId: json['invoiceId'] ?? '',
      orderId: json['orderId'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      issueDate: DateTime.parse(json['issueDate']),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      customerId: customer['id'],
      customerName: customer['name'],
      customerPhone: customer['phone'],
      customerEmail: customer['email'],
      status: json['status'] ?? 'paid',
      lineItems: lineItems,
      subtotal: (financials['subtotal'] as num).toDouble(),
      taxAmount: (financials['taxAmount'] as num).toDouble(),
      discountAmount: (financials['discountAmount'] as num).toDouble(),
      paymentMethod: financials['paymentMethod'] ?? 'cash',
      businessName: business['name'] ?? '',
      businessPhone: business['phone'] ?? '',
      businessEmail: business['email'] ?? '',
      isCreditSale: creditInfo?['isCreditSale'] ?? false,
      creditAmount: (creditInfo?['creditAmount'] as num?)?.toDouble(),
      paidAmount: (creditInfo?['paidAmount'] as num?)?.toDouble(),
      creditDueDate: creditInfo?['dueDate'] != null
          ? DateTime.parse(creditInfo!['dueDate'])
          : null,
      returnPolicy: policies['returnPolicy'],
      warrantyInfo: policies['warrantyInfo'],
      verificationCode: verification['code'] ?? '',
    );
  }


  static String _generateVerificationCode(String invoiceNumber) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return '${invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}-${timestamp.toString().substring(8)}-${random.toString().padLeft(4, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'version': '2.0',
      'type': 'pos_invoice',
      'invoiceId': invoiceId,
      'orderId': orderId,
      'invoiceNumber': invoiceNumber,
      'issueDate': issueDate.toIso8601String(),
      'totalAmount': totalAmount,
      'customer': {
        'id': customerId,
        'name': customerName,
        'phone': customerPhone,
        'email': customerEmail,
      },
      'status': status,
      'lineItems': lineItems.map((item) => item.toJson()).toList(),
      'financials': {
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'discountAmount': discountAmount,
        'paymentMethod': paymentMethod,
      },
      'business': {
        'name': businessName,
        'phone': businessPhone,
        'email': businessEmail,
      },
      'creditInfo': isCreditSale ? {
        'isCreditSale': true,
        'creditAmount': creditAmount,
        'paidAmount': paidAmount,
        'dueDate': creditDueDate?.toIso8601String(),
      } : null,
      'policies': {
        'returnPolicy': returnPolicy,
        'warrantyInfo': warrantyInfo,
      },
      'verification': {
        'code': verificationCode,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'metadata': {
        'currency': Constants.CURRENCY_NAME,
        'generatedAt': DateTime.now().toIso8601String(),
        'schemaVersion': '2.0',
      }
    };
  }

  String toQRString() {
    return jsonEncode(toJson());
  }

  static OrderQRData? fromQRString(String qrString) {
    try {
      final data = jsonDecode(qrString);
      if (data['type'] == 'pos_invoice' && data['version'] == '2.0') {
        return OrderQRData.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }



  // Helper method to get formatted string for display
  String getFormattedSummary() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return '''
INVOICE: $invoiceNumber
ORDER: $orderId
DATE: ${dateFormat.format(issueDate)}
TIME: ${timeFormat.format(issueDate)}
TOTAL: ${Constants.CURRENCY_NAME}${totalAmount.toStringAsFixed(2)}
CUSTOMER: ${customerName ?? 'Walk-in Customer'}
ITEMS: ${lineItems.length}
STATUS: ${status.toUpperCase()}
VERIFICATION: $verificationCode
''';
  }

  // Method to validate if QR code is still valid (within 1 year)
  bool get isValid {
    final oneYearAgo = DateTime.now().subtract(Duration(days: 365));
    return issueDate.isAfter(oneYearAgo);
  }

  // Method to check if return is possible (within 30 days)
  bool get isReturnable {
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
    return issueDate.isAfter(thirtyDaysAgo);
  }

  // Method to get days since purchase
  int get daysSincePurchase {
    return DateTime.now().difference(issueDate).inDays;
  }
}

class QRLineItem {
  final String productName;
  final String productSku;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final bool hasDiscount;
  final double discountAmount;
  final double discountPercent;

  QRLineItem({
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.hasDiscount,
    required this.discountAmount,
    required this.discountPercent,
  });

  Map<String, dynamic> toJson() {
    return {
      'productName': productName,
      'productSku': productSku,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'hasDiscount': hasDiscount,
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
    };
  }

  factory QRLineItem.fromJson(Map<String, dynamic> json) {
    return QRLineItem(
      productName: json['productName'] ?? '',
      productSku: json['productSku'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      hasDiscount: json['hasDiscount'] ?? false,
      discountAmount: (json['discountAmount'] as num).toDouble(),
      discountPercent: (json['discountPercent'] as num).toDouble(),
    );
  }

  String getFormattedLine() {
    final discountText = hasDiscount
        ? ' (Disc: ${Constants.CURRENCY_NAME}${discountAmount.toStringAsFixed(2)})'
        : '';
    return '$productName x$quantity - ${Constants.CURRENCY_NAME}${totalPrice.toStringAsFixed(2)}$discountText';
  }
}



class QRScannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }

  CollectionReference get _ordersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('orders');

  CollectionReference get _returnsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('returns');

  // Process scanned QR code and return order information
  Future<QRScanResult> processScannedQRCode(String qrData, BuildContext context) async {
    try {
      final orderQRData = OrderQRData.fromQRString(qrData);

      if (orderQRData == null) {
        return QRScanResult(
          success: false,
          error: 'Invalid QR code format',
          orderQRData: null,
        );
      }

      // Verify the order exists in database
      final orderDoc = await _ordersRef.doc(orderQRData.orderId).get();

      if (!orderDoc.exists) {
        return QRScanResult(
          success: false,
          error: 'Order not found in system',
          orderQRData: orderQRData,
        );
      }

      // Verify the invoice matches
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final storedInvoiceNumber = orderData['invoiceNumber']?.toString();

      if (storedInvoiceNumber != orderQRData.invoiceNumber) {
        return QRScanResult(
          success: false,
          error: 'Invoice verification failed',
          orderQRData: orderQRData,
        );
      }

      // Check if QR code is still valid
      if (!orderQRData.isValid) {
        return QRScanResult(
          success: false,
          error: 'QR code has expired (over 1 year old)',
          orderQRData: orderQRData,
        );
      }

      return QRScanResult(
        success: true,
        error: null,
        orderQRData: orderQRData,
        firestoreData: orderData,
      );

    } catch (e) {
      return QRScanResult(
        success: false,
        error: 'Error processing QR code: $e',
        orderQRData: null,
      );
    }
  }

  // Process return using QR code
  Future<ReturnProcessResult> processReturn(OrderQRData qrData, List<int> returnItemIndexes, String reason) async {
    try {
      // Check if return is possible
      if (!qrData.isReturnable) {
        return ReturnProcessResult(
          success: false,
          error: 'Return period has ended. Purchase was ${qrData.daysSincePurchase} days ago.',
          returnId: null,
          refundAmount: 0.0,
        );
      }

      // Calculate refund amount for returned items
      double refundAmount = 0.0;
      final returnedItems = <QRLineItem>[];

      for (final index in returnItemIndexes) {
        if (index >= 0 && index < qrData.lineItems.length) {
          final item = qrData.lineItems[index];
          refundAmount += item.totalPrice;
          returnedItems.add(item);
        }
      }

      if (returnedItems.isEmpty) {
        return ReturnProcessResult(
          success: false,
          error: 'No valid items selected for return',
          returnId: null,
          refundAmount: 0.0,
        );
      }

      // Get the original order data to update
      final orderDoc = await _ordersRef.doc(qrData.orderId).get();
      final orderData = orderDoc.data() as Map<String, dynamic>? ?? {};

      // Create return record in Firestore
      final returnId = 'RET-${DateTime.now().millisecondsSinceEpoch}';

      final returnData = {
        'returnId': returnId,
        'originalInvoiceId': qrData.invoiceId,
        'originalOrderId': qrData.orderId,
        'invoiceNumber': qrData.invoiceNumber,
        'customerId': qrData.customerId,
        'customerName': qrData.customerName,
        'customerPhone': qrData.customerPhone,
        'customerEmail': qrData.customerEmail,
        'returnDate': DateTime.now().toIso8601String(),
        'refundAmount': refundAmount,
        'returnReason': reason,
        'returnedItems': returnedItems.map((item) => item.toJson()).toList(),
        'originalPurchaseDate': qrData.issueDate.toIso8601String(),
        'verificationCode': qrData.verificationCode,
        'status': 'processed',
        'processedBy': 'system', // You can replace with actual user ID
        'processedAt': DateTime.now().toIso8601String(),
        'businessName': qrData.businessName,
        'businessPhone': qrData.businessPhone,
      };

      await _returnsRef.doc(returnId).set(returnData);

      // Update original order with return information
      final currentReturnAmount = (orderData['returnAmount'] as num?)?.toDouble() ?? 0.0;
      final currentRefundAmount = (orderData['totalRefunded'] as num?)?.toDouble() ?? 0.0;

      await _ordersRef.doc(qrData.orderId).update({
        'hasReturns': true,
        'returnAmount': currentReturnAmount + refundAmount,
        'totalRefunded': currentRefundAmount + refundAmount,
        'lastReturnDate': DateTime.now().toIso8601String(),
        'returnStatus': 'partially_returned', // or 'fully_returned' if all items returned
        'modifiedAt': DateTime.now().toIso8601String(),
      });

      return ReturnProcessResult(
        success: true,
        error: null,
        returnId: returnId,
        refundAmount: refundAmount,
        returnedItems: returnedItems,
      );

    } catch (e) {
      return ReturnProcessResult(
        success: false,
        error: 'Error processing return: $e',
        returnId: null,
        refundAmount: 0.0,
      );
    }
  }

  // Process exchange using QR code
  Future<ExchangeProcessResult> processExchange(
      OrderQRData qrData,
      List<int> exchangeItemIndexes,
      List<Map<String, dynamic>> newItems,
      String reason
      ) async {
    try {
      // Check if exchange is possible
      if (!qrData.isReturnable) {
        return ExchangeProcessResult(
          success: false,
          error: 'Exchange period has ended. Purchase was ${qrData.daysSincePurchase} days ago.',
          exchangeId: null,
        );
      }

      // Calculate values for exchanged items
      double originalValue = 0.0;
      double newValue = 0.0;
      final exchangedItems = <QRLineItem>[];

      for (final index in exchangeItemIndexes) {
        if (index >= 0 && index < qrData.lineItems.length) {
          final item = qrData.lineItems[index];
          originalValue += item.totalPrice;
          exchangedItems.add(item);
        }
      }

      for (final newItem in newItems) {
        final price = (newItem['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (newItem['quantity'] as num?)?.toInt() ?? 1;
        newValue += price * quantity;
      }

      if (exchangedItems.isEmpty) {
        return ExchangeProcessResult(
          success: false,
          error: 'No valid items selected for exchange',
          exchangeId: null,
        );
      }

      // Create exchange record in Firestore
      final exchangeId = 'EXC-${DateTime.now().millisecondsSinceEpoch}';

      final exchangeData = {
        'exchangeId': exchangeId,
        'originalInvoiceId': qrData.invoiceId,
        'originalOrderId': qrData.orderId,
        'invoiceNumber': qrData.invoiceNumber,
        'customerId': qrData.customerId,
        'customerName': qrData.customerName,
        'exchangeDate': DateTime.now().toIso8601String(),
        'originalValue': originalValue,
        'newValue': newValue,
        'valueDifference': newValue - originalValue,
        'exchangeReason': reason,
        'exchangedItems': exchangedItems.map((item) => item.toJson()).toList(),
        'newItems': newItems,
        'originalPurchaseDate': qrData.issueDate.toIso8601String(),
        'verificationCode': qrData.verificationCode,
        'status': 'processed',
        'processedBy': 'system',
        'processedAt': DateTime.now().toIso8601String(),
      };

      await _returnsRef.doc(exchangeId).set(exchangeData);

      return ExchangeProcessResult(
        success: true,
        error: null,
        exchangeId: exchangeId,
        originalValue: originalValue,
        newValue: newValue,
        valueDifference: newValue - originalValue,
      );

    } catch (e) {
      return ExchangeProcessResult(
        success: false,
        error: 'Error processing exchange: $e',
        exchangeId: null,
      );
    }
  }

  // Get return history for an order
  Future<List<ReturnRecord>> getReturnHistory(String orderId) async {
    try {
      final snapshot = await _returnsRef
          .where('originalOrderId', isEqualTo: orderId)
          .where('status', isEqualTo: 'processed')
          .orderBy('returnDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ReturnRecord.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get exchange history for an order
  Future<List<ExchangeRecord>> getExchangeHistory(String orderId) async {
    try {
      final snapshot = await _returnsRef
          .where('originalOrderId', isEqualTo: orderId)
          .where('status', isEqualTo: 'processed')
          .orderBy('exchangeDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ExchangeRecord.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Validate if an item can be returned (not already returned)
  Future<bool> validateItemReturn(String orderId, int itemIndex) async {
    try {
      final returns = await getReturnHistory(orderId);

      for (final returnRecord in returns) {
        for (final returnedItem in returnRecord.returnedItems) {
          if (returnedItem is Map<String, dynamic>) {
            final originalIndex = returnedItem['originalIndex'] as int?;
            if (originalIndex == itemIndex) {
              return false; // Item already returned
            }
          }
        }
      }

      return true; // Item can be returned
    } catch (e) {
      return false;
    }
  }

  // Get customer return statistics
  Future<CustomerReturnStats> getCustomerReturnStats(String customerId) async {
    try {
      final returnsSnapshot = await _returnsRef
          .where('customerId', isEqualTo: customerId)
          .where('status', isEqualTo: 'processed')
          .get();

      final returns = returnsSnapshot.docs;
      double totalRefunded = 0.0;
      int totalReturns = returns.length;
      Set<String> returnedOrders = {};

      for (final returnDoc in returns) {
        final data = returnDoc.data() as Map<String, dynamic>;
        totalRefunded += (data['refundAmount'] as num?)?.toDouble() ?? 0.0;
        returnedOrders.add(data['originalOrderId']?.toString() ?? '');
      }

      return CustomerReturnStats(
        customerId: customerId,
        totalReturns: totalReturns,
        totalRefunded: totalRefunded,
        uniqueOrdersReturned: returnedOrders.length,
        averageRefund: totalReturns > 0 ? totalRefunded / totalReturns : 0.0,
        lastReturnDate: returns.isNotEmpty
            ? DateTime.parse(returns.first['returnDate'] as String)
            : null,
      );
    } catch (e) {
      return CustomerReturnStats(
        customerId: customerId,
        totalReturns: 0,
        totalRefunded: 0.0,
        uniqueOrdersReturned: 0,
        averageRefund: 0.0,
        lastReturnDate: null,
      );
    }
  }
}

class QRScanResult {
  final bool success;
  final String? error;
  final OrderQRData? orderQRData;
  final Map<String, dynamic>? firestoreData;

  QRScanResult({
    required this.success,
    required this.error,
    required this.orderQRData,
    this.firestoreData,
  });

  bool get canReturn => orderQRData?.isReturnable ?? false;
  int get daysLeftForReturn => orderQRData?.isReturnable == true
      ? (30 - (orderQRData?.daysSincePurchase ?? 0))
      : 0;
}

class ReturnProcessResult {
  final bool success;
  final String? error;
  final String? returnId;
  final double refundAmount;
  final List<QRLineItem>? returnedItems;

  ReturnProcessResult({
    required this.success,
    required this.error,
    required this.returnId,
    required this.refundAmount,
    this.returnedItems,
  });
}

class ExchangeProcessResult {
  final bool success;
  final String? error;
  final String? exchangeId;
  final double? originalValue;
  final double? newValue;
  final double? valueDifference;

  ExchangeProcessResult({
    required this.success,
    required this.error,
    required this.exchangeId,
    this.originalValue,
    this.newValue,
    this.valueDifference,
  });
}

class ReturnRecord {
  final String returnId;
  final String originalInvoiceId;
  final String originalOrderId;
  final String invoiceNumber;
  final DateTime returnDate;
  final double refundAmount;
  final String returnReason;
  final String status;
  final List<dynamic> returnedItems;
  final String? customerName;
  final String? customerPhone;

  ReturnRecord({
    required this.returnId,
    required this.originalInvoiceId,
    required this.originalOrderId,
    required this.invoiceNumber,
    required this.returnDate,
    required this.refundAmount,
    required this.returnReason,
    required this.status,
    required this.returnedItems,
    this.customerName,
    this.customerPhone,
  });

  factory ReturnRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return ReturnRecord(
      returnId: id,
      originalInvoiceId: data['originalInvoiceId'] ?? '',
      originalOrderId: data['originalOrderId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      returnDate: DateTime.parse(data['returnDate'] ?? DateTime.now().toIso8601String()),
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
      returnReason: data['returnReason'] ?? '',
      status: data['status'] ?? 'processed',
      returnedItems: data['returnedItems'] ?? [],
      customerName: data['customerName'],
      customerPhone: data['customerPhone'],
    );
  }

  String get formattedReturnDate {
    return '${returnDate.day}/${returnDate.month}/${returnDate.year}';
  }

  int get returnedItemCount {
    return returnedItems.length;
  }
}

class ExchangeRecord {
  final String exchangeId;
  final String originalOrderId;
  final String invoiceNumber;
  final DateTime exchangeDate;
  final double originalValue;
  final double newValue;
  final double valueDifference;
  final String exchangeReason;
  final String status;
  final List<dynamic> exchangedItems;
  final List<dynamic> newItems;

  ExchangeRecord({
    required this.exchangeId,
    required this.originalOrderId,
    required this.invoiceNumber,
    required this.exchangeDate,
    required this.originalValue,
    required this.newValue,
    required this.valueDifference,
    required this.exchangeReason,
    required this.status,
    required this.exchangedItems,
    required this.newItems,
  });

  factory ExchangeRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return ExchangeRecord(
      exchangeId: id,
      originalOrderId: data['originalOrderId'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      exchangeDate: DateTime.parse(data['exchangeDate'] ?? DateTime.now().toIso8601String()),
      originalValue: (data['originalValue'] as num?)?.toDouble() ?? 0.0,
      newValue: (data['newValue'] as num?)?.toDouble() ?? 0.0,
      valueDifference: (data['valueDifference'] as num?)?.toDouble() ?? 0.0,
      exchangeReason: data['exchangeReason'] ?? '',
      status: data['status'] ?? 'processed',
      exchangedItems: data['exchangedItems'] ?? [],
      newItems: data['newItems'] ?? [],
    );
  }

  bool get requiresAdditionalPayment => valueDifference > 0;
  bool get providesRefund => valueDifference < 0;
}

class CustomerReturnStats {
  final String customerId;
  final int totalReturns;
  final double totalRefunded;
  final int uniqueOrdersReturned;
  final double averageRefund;
  final DateTime? lastReturnDate;

  CustomerReturnStats({
    required this.customerId,
    required this.totalReturns,
    required this.totalRefunded,
    required this.uniqueOrdersReturned,
    required this.averageRefund,
    required this.lastReturnDate,
  });

  double get returnRate {
    return uniqueOrdersReturned > 0 ? totalReturns / uniqueOrdersReturned : 0.0;
  }

  String get returnBehavior {
    if (totalReturns == 0) return 'No Returns';
    if (returnRate < 0.1) return 'Low Return Rate';
    if (returnRate < 0.3) return 'Moderate Return Rate';
    return 'High Return Rate';
  }

}



