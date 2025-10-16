import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../app.dart';
import '../constants.dart';
import 'invoice_model.dart';

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  // Generate PDF Invoice
  Future<File> generatePdfInvoice(Invoice invoice) async {
    final pdf = pw.Document();

    if (invoice.templateType == 'thermal') {
      _buildThermalInvoice(pdf, invoice);
    } else {
      _buildTraditionalInvoice(pdf, invoice);
    }

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  void _buildThermalInvoice(pw.Document pdf, Invoice invoice) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll57,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildThermalHeader(invoice),
              pw.SizedBox(height: 10),

              // Customer Info
              if (invoice.showCustomerDetails && invoice.customer != null)
                _buildThermalCustomerInfo(invoice.customer!),
              pw.SizedBox(height: 10),

              // Items
              _buildThermalItems(invoice),
              pw.SizedBox(height: 10),

              // Totals
              _buildThermalTotals(invoice),
              pw.SizedBox(height: 10),

              // Footer
              _buildThermalFooter(invoice),
            ],
          );
        },
      ),
    );
  }

  void _buildTraditionalInvoice(pw.Document pdf, Invoice invoice) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logo
              _buildTraditionalHeader(invoice),
              pw.SizedBox(height: 20),

              // Invoice and Customer Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInvoiceDetails(invoice),
                  pw.SizedBox(width: 50),
                  if (invoice.showCustomerDetails) _buildCustomerDetails(invoice.customer!),
                ],
              ),
              pw.SizedBox(height: 20),

              // Items Table
              _buildTraditionalItemsTable(invoice),
              pw.SizedBox(height: 20),

              // Totals
              _buildTraditionalTotals(invoice),
              pw.SizedBox(height: 20),

              // Notes and Footer
              _buildTraditionalFooter(invoice),
            ],
          );
        },
      ),
    );
  }

  // Thermal Invoice Components
  pw.Widget _buildThermalHeader(Invoice invoice) {
    final business = invoice.businessInfo;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          business['name']?.toString() ?? 'BUSINESS NAME',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
        if (business['address'] != null)
          pw.Text(
            business['address']!,
            style: pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        if (business['phone'] != null)
          pw.Text(
            'Tel: ${business['phone']!}',
            style: pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        if (business['email'] != null)
          pw.Text(
            'Email: ${business['email']!}',
            style: pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        pw.Divider(),
        pw.Text(
          'INVOICE: ${invoice.invoiceNumber}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
        pw.Text(
          'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(invoice.issueDate)}',
          style: pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  pw.Widget _buildThermalCustomerInfo(Customer customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CUSTOMER:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        ),
        pw.Text(customer.fullName, style: pw.TextStyle(fontSize: 8)),
        if (customer.phone.isNotEmpty)
          pw.Text('Tel: ${customer.phone}', style: pw.TextStyle(fontSize: 8)),
        if (customer.email.isNotEmpty)
          pw.Text('Email: ${customer.email}', style: pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildThermalItems(Invoice invoice) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(2),
              child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(2),
              child: pw.Text('QTY', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(2),
              child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        ...invoice.items.map((item) => pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.name, style: pw.TextStyle(fontSize: 8)),
                  if (item.description.isNotEmpty)
                    pw.Text(item.description, style: pw.TextStyle(fontSize: 6)),
                  // Show discount if available
                  if (invoice.hasEnhancedPricing && item.hasManualDiscount)
                    pw.Text(
                      'Disc: -${Constants.CURRENCY_NAME}${item.discountAmount?.toStringAsFixed(2) ?? '0.00'}',
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.red),
                    ),
                ],
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(2),
              child: pw.Text(item.quantity.toString(), style: pw.TextStyle(fontSize: 8)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(2),
              child: pw.Text('${Constants.CURRENCY_NAME}${item.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 8)),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildThermalTotals(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 9)),
            pw.Text('${Constants.CURRENCY_NAME}${invoice.subtotal.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 9)),
          ],
        ),

        // Enhanced pricing breakdown
        if (invoice.hasEnhancedPricing && invoice.showCartDiscount)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Cart Discount:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('-${Constants.CURRENCY_NAME}${invoice.cartDiscountAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.red)),
            ],
          ),

        if (invoice.hasEnhancedPricing && invoice.showAdditionalDiscount)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Additional Discount:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('-${Constants.CURRENCY_NAME}${invoice.additionalDiscount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.red)),
            ],
          ),

        if (invoice.hasEnhancedPricing && invoice.showShipping)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Shipping:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('${Constants.CURRENCY_NAME}${invoice.shippingAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9)),
            ],
          ),

        if (invoice.taxAmount > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tax:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('${Constants.CURRENCY_NAME}${invoice.taxAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9)),
            ],
          ),

        if (invoice.discountAmount > 0 && !invoice.hasEnhancedPricing)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Discount:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('-${Constants.CURRENCY_NAME}${invoice.discountAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.red)),
            ],
          ),

        if (invoice.hasEnhancedPricing && invoice.showTip)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tip:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('${Constants.CURRENCY_NAME}${invoice.tipAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9)),
            ],
          ),

        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text('${Constants.CURRENCY_NAME}${invoice.totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text('Payment Method: ${invoice.paymentMethod.toUpperCase()}',
            style: pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildThermalFooter(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.Text(
          invoice.notes,
          style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // Traditional Invoice Components
  pw.Widget _buildTraditionalHeader(Invoice invoice) {
    final business = invoice.businessInfo;
    return pw.Row(
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
          ],
        ),
        // You can add logo here
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
      ],
    );
  }

  pw.Widget _buildInvoiceDetails(Invoice invoice) {
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
                  // Show discount details for enhanced pricing
                  if (invoice.hasEnhancedPricing && item.hasManualDiscount)
                    pw.Text(
                      'Discount: -${Constants.CURRENCY_NAME}${item.discountAmount?.toStringAsFixed(2) ?? '0.00'} (${item.manualDiscountPercent?.toStringAsFixed(1) ?? '0'}%)',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.red),
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

  pw.Widget _buildTraditionalTotals(Invoice invoice) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    _totalRow('Subtotal', invoice.subtotal),

                    // Enhanced pricing breakdown
                    if (invoice.hasEnhancedPricing && invoice.showCartDiscount)
                      _totalRow('Cart Discount', -invoice.cartDiscountAmount, isDiscount: true),

                    if (invoice.hasEnhancedPricing && invoice.showAdditionalDiscount)
                      _totalRow('Additional Discount', -invoice.additionalDiscount, isDiscount: true),

                    if (invoice.hasEnhancedPricing && invoice.showShipping)
                      _totalRow('Shipping', invoice.shippingAmount),

                    if (invoice.taxAmount > 0)
                      _totalRow('Tax', invoice.taxAmount),

                    if (invoice.discountAmount > 0 && !invoice.hasEnhancedPricing)
                      _totalRow('Discount', -invoice.discountAmount, isDiscount: true),

                    if (invoice.hasEnhancedPricing && invoice.showTip)
                      _totalRow('Tip', invoice.tipAmount),

                    pw.Divider(),
                    _totalRow('TOTAL', invoice.totalAmount, isTotal: true),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Payment Method: ${invoice.paymentMethod}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _totalRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(
            '${isDiscount && amount > 0 ? '-' : ''}${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isDiscount ? PdfColors.red : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTraditionalFooter(Invoice invoice) {
    final business = invoice.businessInfo;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
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

  // Print Invoice
  Future<void> printInvoice(Invoice invoice) async {
    final pdfFile = await generatePdfInvoice(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await pdfFile.readAsBytes();
      },
    );
  }

  // Share/Export Invoice
  Future<void> shareInvoice(Invoice invoice) async {
    final pdfFile = await generatePdfInvoice(invoice);
    await Share.shareXFiles([XFile(pdfFile.path)], text: 'Invoice ${invoice.invoiceNumber}');
  }

  // Print directly (for thermal printers)
  Future<void> printDirect(Invoice invoice) async {
    if (invoice.templateType == 'thermal') {
      await _printThermalInvoice(invoice);
    } else {
      await _printTraditionalInvoice(invoice);
    }
  }

  Future<void> _printThermalInvoice(Invoice invoice) async {
    // Thermal printer implementation
    print('Printing thermal invoice: ${invoice.invoiceNumber}');

    if (invoice.hasEnhancedPricing) {
      await _printEnhancedThermalInvoice(invoice);
    } else {
      await _printBasicThermalInvoice(invoice);
    }
  }

  Future<void> _printTraditionalInvoice(Invoice invoice) async {
    // Traditional A4 printer implementation
    print('Printing traditional invoice: ${invoice.invoiceNumber}');

    if (invoice.hasEnhancedPricing) {
      await _printEnhancedTraditionalInvoice(invoice);
    } else {
      await _printBasicTraditionalInvoice(invoice);
    }
  }

  Future<void> _printEnhancedThermalInvoice(Invoice invoice) async {
    // Implementation for enhanced thermal printing with discounts
    // This would integrate with your actual thermal printer library
    print('Enhanced thermal invoice with discounts: ${invoice.invoiceNumber}');
    await printInvoice(invoice); // Fallback to PDF printing
  }

  Future<void> _printBasicThermalInvoice(Invoice invoice) async {
    // Basic thermal printing (original implementation)
    print('Basic thermal invoice: ${invoice.invoiceNumber}');
    await printInvoice(invoice); // Fallback to PDF printing
  }

  Future<void> _printEnhancedTraditionalInvoice(Invoice invoice) async {
    // Implementation for enhanced traditional printing
    print('Enhanced traditional invoice with detailed breakdown: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }

  Future<void> _printBasicTraditionalInvoice(Invoice invoice) async {
    // Basic traditional printing (original implementation)
    print('Basic traditional invoice: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }
}