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
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _buildProfessionalThermalHeader(invoice),
                pw.SizedBox(height: 8),
                _buildThermalInvoiceDetails(invoice),
                pw.SizedBox(height: 8),
                if (invoice.showCustomerDetails && invoice.customer != null)
                  _buildCompactCustomerInfo(invoice.customer!),
                if (invoice.showCustomerDetails && invoice.customer != null)
                  pw.SizedBox(height: 8),
                _buildProfessionalItemsTable(invoice),
                pw.SizedBox(height: 8),
                _buildEnhancedThermalTotals(invoice),
                pw.SizedBox(height: 8),
                _buildPaymentAndFooter(invoice),
                pw.SizedBox(height: 8),
                _buildCompactQRCode(invoice),
                pw.SizedBox(height: 8),
                _buildThankYouFooter(invoice),
              ],
            ),
          );
        },
      ),
    );
  }

  pw.Widget _buildProfessionalThermalHeader(Invoice invoice) {
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

  pw.Widget _buildThermalInvoiceDetails(Invoice invoice) {
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
        if (invoice.orderId.isNotEmpty)
          pw.Text(
            'Order: ${invoice.orderId}',
            style: pw.TextStyle(fontSize: 8),
          ),
      ],
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

          // ALWAYS SHOW TAX - FIXED
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
                  'TOTAL AMOUNT:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.Text(
                  '${Constants.CURRENCY_NAME}${invoice.totalAmount.toStringAsFixed(2)}',
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
                  // Add tax to savings breakdown if applicable
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

  String _getDiscountLabel(String discountType) {
    switch (discountType) {
      case 'item_discounts':
        return '  • Item Discounts';
      case 'cart_discount':
        return '  • Cart Discount';
      case 'additional_discount':
        return '  • Additional Discount';
      case 'settings_discount':
        return '  • Standard Discount';
      case 'legacy_discount':
        return '  • Discount';
      default:
        return '  • $discountType';
    }
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

  pw.Widget _buildPaymentAndFooter(Invoice invoice) {
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
            children: [
              pw.Text(
                'Payment Method:',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                invoice.paymentMethod.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
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
          pw.Text(
            'Scan for order details',
            style: pw.TextStyle(fontSize: 6),
          ),
          pw.Text(
            '& returns',
            style: pw.TextStyle(fontSize: 6),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Ref: ${invoice.invoiceNumber}',
            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _generateQRData(Invoice invoice) {
    return '''
INVOICE REFERENCE
Invoice: ${invoice.invoiceNumber}
Order: ${invoice.orderId}
Date: ${DateFormat('dd/MM/yyyy').format(invoice.issueDate)}
Total: ${Constants.CURRENCY_NAME}${invoice.totalAmount.toStringAsFixed(2)}
Business: ${invoice.businessInfo['name']}
Customer: ${invoice.customer?.fullName ?? 'Walk-in'}
For returns or inquiries, present this QR code
    ''';
  }

  pw.Widget _buildThankYouFooter(Invoice invoice) {
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
        ],
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
              _buildTraditionalHeader(invoice),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInvoiceDetails(invoice),
                  pw.SizedBox(width: 50),
                  if (invoice.showCustomerDetails && invoice.customer != null)
                    _buildCustomerDetails(invoice.customer!),
                ],
              ),
              pw.SizedBox(height: 20),
              _buildTraditionalItemsTable(invoice),
              pw.SizedBox(height: 20),
              _buildEnhancedTraditionalTotals(invoice),
              pw.SizedBox(height: 20),
              pw.Center(
                child: _buildTraditionalQRCode(invoice),
              ),
              pw.SizedBox(height: 20),
              _buildTraditionalFooter(invoice),
            ],
          );
        },
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

                    // ALWAYS SHOW TAX - FIXED
                    if (invoice.taxAmount > 0)
                      _enhancedTotalRow('Tax', invoice.taxAmount),

                    if (hasEnhanced && invoice.showShipping)
                      _enhancedTotalRow('Shipping', invoice.shippingAmount),

                    if (hasEnhanced && invoice.showTip)
                      _enhancedTotalRow('Tip', invoice.tipAmount),

                    pw.Divider(thickness: 2),
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

                            // Always show tax breakdown
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

  Future<void> printInvoice(Invoice invoice) async {
    final pdfFile = await generatePdfInvoice(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await pdfFile.readAsBytes();
      },
    );
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
    print('Enhanced thermal invoice with independent discounts: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }

  Future<void> _printBasicThermalInvoice(Invoice invoice) async {
    print('Basic thermal invoice: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }

  Future<void> _printEnhancedTraditionalInvoice(Invoice invoice) async {
    print('Enhanced traditional invoice with detailed breakdown: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }

  Future<void> _printBasicTraditionalInvoice(Invoice invoice) async {
    print('Basic traditional invoice: ${invoice.invoiceNumber}');
    await printInvoice(invoice);
  }
}


