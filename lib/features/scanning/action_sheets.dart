// Enhanced QR Scanning Service for Dashboard
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

// Your existing imports
import '../../constants.dart';
import '../../printing/invoice_service.dart';
import '../invoiceBase/invoice_and_printing_base.dart';
import '../orderBase/order_base.dart';
import '../barcode/barcode_base.dart'; //
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

class SmartQRScanService {
  static final SmartQRScanService _instance = SmartQRScanService._internal();
  factory SmartQRScanService() => _instance;
  SmartQRScanService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InvoiceService _invoiceService = InvoiceService();

  // Smart QR Code Processing with AI-like intelligence
  Future<SmartQRScanResult> processQRCode(String qrData) async {
    try {
      // Try multiple QR code formats with priority
      QRScanData? scanData = await _tryAllFormats(qrData);

      if (scanData == null) {
        return SmartQRScanResult.error('Unrecognized QR code format');
      }

      // Enhanced data enrichment
      final enrichedData = await _enrichScanData(scanData);

      return SmartQRScanResult.success(
        scanData: scanData,
        enrichedData: enrichedData,
      );
    } catch (e) {
      return SmartQRScanResult.error('Processing failed: $e');
    }
  }

  Future<QRScanData?> _tryAllFormats(String qrData) async {
    // Priority 1: New OrderQRData format (v2.0)
    try {
      final orderQR = OrderQRData.fromQRString(qrData);
      if (orderQR != null) {
        return QRScanData.fromOrderQR(orderQR);
      }
    } catch (e) {
      print('Failed to parse as OrderQRData: $e');
    }

    // Priority 2: Legacy InvoiceQRData format
    try {
      final invoiceQR = InvoiceQRData.fromQRString(qrData);
      if (invoiceQR != null) {
        return QRScanData.fromInvoiceQR(invoiceQR);
      }
    } catch (e) {
      print('Failed to parse as InvoiceQRData: $e');
    }

    // Priority 3: JSON with type detection
    try {
      final jsonData = jsonDecode(qrData);
      return QRScanData.fromJson(jsonData);
    } catch (e) {
      print('Failed to parse as JSON: $e');
    }

    // Priority 4: Plain text analysis
    return await _analyzePlainText(qrData);
  }

  Future<QRScanData?> _analyzePlainText(String text) async {
    // Advanced pattern matching for common order/invoice formats
    final patterns = [
      RegExp(r'INV[-_]?(\d+)', caseSensitive: false),
      RegExp(r'ORDER[-_]?(\d+)', caseSensitive: false),
      RegExp(r'#?(\d{6,})'), // Numeric IDs
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final potentialId = match.group(1);
        if (potentialId != null) {
          // Try to find in database
          final data = await _lookupInDatabase(potentialId, text);
          if (data != null) return data;
        }
      }
    }

    return null;
  }

  Future<QRScanData?> _lookupInDatabase(String id, String originalText) async {
    try {
      // Try orders collection
      final orderSnapshot = await _firestore
          .collection('orders')
          .where('number', isEqualTo: id)
          .limit(1)
          .get();

      if (orderSnapshot.docs.isNotEmpty) {
        final orderData = orderSnapshot.docs.first.data();
        return QRScanData.fromFirestore(orderData, 'order');
      }

      // Try invoices collection
      final invoiceSnapshot = await _firestore
          .collection('invoices')
          .where('invoiceNumber', isEqualTo: id)
          .limit(1)
          .get();

      if (invoiceSnapshot.docs.isNotEmpty) {
        final invoiceData = invoiceSnapshot.docs.first.data();
        return QRScanData.fromFirestore(invoiceData, 'invoice');
      }
    } catch (e) {
      print('Database lookup failed: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>> _enrichScanData(QRScanData scanData) async {
    final enriched = <String, dynamic>{};

    // Add timestamp and context
    enriched['scannedAt'] = DateTime.now();
    enriched['confidenceScore'] = _calculateConfidence(scanData);

    // Fetch additional data if we have an ID
    if (scanData.orderId.isNotEmpty) {
      try {
        final orderDoc = await _firestore
            .collection('orders')
            .doc(scanData.orderId)
            .get();

        if (orderDoc.exists) {
          enriched['orderDetails'] = orderDoc.data();
          enriched['customerHistory'] = await _getCustomerHistory(scanData);
          enriched['relatedDocuments'] = await _getRelatedDocuments(scanData);
        }
      } catch (e) {
        print('Data enrichment failed: $e');
      }
    }

    // Add analytics data
    enriched['analytics'] = {
      'daysSinceCreation': scanData.creationDate != null
          ? DateTime.now().difference(scanData.creationDate!).inDays
          : null,
      'isRecent': scanData.creationDate != null
          ? DateTime.now().difference(scanData.creationDate!).inDays <= 7
          : null,
      'valueCategory': _categorizeValue(scanData.totalAmount),
    };

    return enriched;
  }

  double _calculateConfidence(QRScanData data) {
    double score = 0.0;

    if (data.orderId.isNotEmpty) score += 0.3;
    if (data.invoiceNumber.isNotEmpty) score += 0.3;
    if (data.totalAmount > 0) score += 0.2;
    if (data.customerName.isNotEmpty) score += 0.2;

    return score.clamp(0.0, 1.0);
  }

  String _categorizeValue(double amount) {
    if (amount < 50) return 'Small';
    if (amount < 200) return 'Medium';
    if (amount < 500) return 'Large';
    return 'Premium';
  }

  Future<Map<String, dynamic>> _getCustomerHistory(QRScanData data) async {
    if (data.customerId.isEmpty) return {};

    try {
      final customerOrders = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: data.customerId)
          .limit(10)
          .get();

      return {
        'totalOrders': customerOrders.size,
        'totalSpent': customerOrders.docs.fold(0.0, (sum, doc) {
          final orderData = doc.data();
          return sum + (orderData['total'] ?? 0.0);
        }),
        'lastOrder': customerOrders.docs.isNotEmpty
            ? (customerOrders.docs.first.data()['dateCreated'] as Timestamp).toDate()
            : null,
      };
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _getRelatedDocuments(QRScanData data) async {
    final related = <Map<String, dynamic>>[];

    try {
      // Look for returns
      final returns = await _firestore
          .collection('returns')
          .where('orderId', isEqualTo: data.orderId)
          .get();

      for (final returnDoc in returns.docs) {
        related.add({
          'type': 'return',
          'id': returnDoc.id,
          'date': (returnDoc.data()['returnDate'] as Timestamp).toDate(),
          'amount': returnDoc.data()['refundAmount'] ?? 0.0,
        });
      }

      // Look for exchanges
      final exchanges = await _firestore
          .collection('exchanges')
          .where('orderId', isEqualTo: data.orderId)
          .get();

      for (final exchangeDoc in exchanges.docs) {
        related.add({
          'type': 'exchange',
          'id': exchangeDoc.id,
          'date': (exchangeDoc.data()['exchangeDate'] as Timestamp).toDate(),
        });
      }
    } catch (e) {
      print('Error fetching related documents: $e');
    }

    return related;
  }

  // Generate professional report PDF
  Future<File> generateSmartReport(QRScanData data, Map<String, dynamic> enrichedData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildSmartReportLayout(data, enrichedData);
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/qr_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  pw.Widget _buildSmartReportLayout(QRScanData data, Map<String, dynamic> enrichedData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        _buildReportHeader(data),
        pw.SizedBox(height: 20),

        // Key Information
        _buildKeyInformation(data),
        pw.SizedBox(height: 20),

        // Customer Insights
        if (enrichedData['customerHistory'] != null)
          _buildCustomerInsights(enrichedData['customerHistory']),

        // Related Documents
        if ((enrichedData['relatedDocuments'] as List).isNotEmpty)
          _buildRelatedDocuments(enrichedData['relatedDocuments']),

        // Analytics
        _buildAnalyticsSection(enrichedData['analytics']),

        // Footer
        pw.Spacer(),
        _buildReportFooter(),
      ],
    );
  }

  pw.Widget _buildReportHeader(QRScanData data) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SMART QR CODE REPORT',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              'Generated on ${DateFormat('MMMM dd, yyyy - HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Container(
          width: 60,
          height: 60,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: data.rawData,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildKeyInformation(QRScanData data) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'KEY INFORMATION',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              _buildInfoRow('Document Type', data.documentType.toUpperCase()),
              if (data.invoiceNumber.isNotEmpty)
                _buildInfoRow('Invoice Number', data.invoiceNumber),
              if (data.orderId.isNotEmpty)
                _buildInfoRow('Order ID', data.orderId),
              if (data.creationDate != null)
                _buildInfoRow(
                  'Creation Date',
                  DateFormat('MMM dd, yyyy').format(data.creationDate!),
                ),
              if (data.totalAmount > 0)
                _buildInfoRow(
                  'Total Amount',
                  '${Constants.CURRENCY_NAME}${data.totalAmount.toStringAsFixed(2)}',
                ),
              if (data.customerName.isNotEmpty)
                _buildInfoRow('Customer', data.customerName),
              if (data.customerEmail.isNotEmpty)
                _buildInfoRow('Email', data.customerEmail),
              if (data.customerPhone.isNotEmpty)
                _buildInfoRow('Phone', data.customerPhone),
            ],
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildInfoRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value),
        ),
      ],
    );
  }

  pw.Widget _buildCustomerInsights(Map<String, dynamic> history) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CUSTOMER INSIGHTS',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              _buildInfoRow('Total Orders', history['totalOrders'].toString()),
              _buildInfoRow(
                'Total Lifetime Value',
                '${Constants.CURRENCY_NAME}${(history['totalSpent'] as double).toStringAsFixed(2)}',
              ),
              if (history['lastOrder'] != null)
                _buildInfoRow(
                  'Last Order Date',
                  DateFormat('MMM dd, yyyy').format(history['lastOrder']),
                ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRelatedDocuments(List<Map<String, dynamic>> documents) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RELATED DOCUMENTS',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange700,
            ),
          ),
          pw.SizedBox(height: 12),
          ...documents.map((doc) => pw.Padding(
            padding: pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 8,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: doc['type'] == 'return' ? PdfColors.red : PdfColors.blue,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  '${doc['type'].toString().toUpperCase()} - ${DateFormat('MMM dd, yyyy').format(doc['date'])}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Spacer(),
                if (doc['amount'] != null && doc['amount'] > 0)
                  pw.Text(
                    '${Constants.CURRENCY_NAME}${doc['amount'].toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  pw.Widget _buildAnalyticsSection(Map<String, dynamic> analytics) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.purple200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ANALYTICS',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              if (analytics['daysSinceCreation'] != null)
                _buildInfoRow('Age', '${analytics['daysSinceCreation']} days'),
              if (analytics['isRecent'] != null)
                _buildInfoRow('Recency', analytics['isRecent'] ? 'Recent' : 'Historical'),
              if (analytics['valueCategory'] != null)
                _buildInfoRow('Value Category', analytics['valueCategory']),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReportFooter() {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Report Generated by Smart QR Scanner',
            style: pw.TextStyle(
              fontSize: 12,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Confidential Business Document',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }
}

// Data Models for Smart Scanning
class QRScanData {
  final String rawData;
  final String documentType; // 'order', 'invoice', 'return', etc.
  final String invoiceNumber;
  final String orderId;
  final DateTime? creationDate;
  final double totalAmount;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String customerId;
  final Map<String, dynamic>? originalData;

  QRScanData({
    required this.rawData,
    required this.documentType,
    this.invoiceNumber = '',
    this.orderId = '',
    this.creationDate,
    this.totalAmount = 0.0,
    this.customerName = '',
    this.customerEmail = '',
    this.customerPhone = '',
    this.customerId = '',
    this.originalData,
  });

  factory QRScanData.fromOrderQR(OrderQRData orderQR) {
    return QRScanData(
      rawData: orderQR.toQRString(),
      documentType: 'order',
      invoiceNumber: orderQR.invoiceNumber,
      orderId: orderQR.orderId,
      creationDate: orderQR.issueDate,
      totalAmount: orderQR.totalAmount,
      customerName: orderQR.customerName ?? '',
      customerEmail: orderQR.customerEmail ?? '',
      customerPhone: orderQR.customerPhone ?? '',
      customerId: orderQR.customerId ?? '',
      originalData: orderQR.toJson(),
    );
  }

  factory QRScanData.fromInvoiceQR(InvoiceQRData invoiceQR) {
    return QRScanData(
      rawData: invoiceQR.toQRString(),
      documentType: 'invoice',
      invoiceNumber: invoiceQR.invoiceNumber,
      orderId: invoiceQR.orderId,
      creationDate: invoiceQR.issueDate,
      totalAmount: invoiceQR.totalAmount,
      customerName: invoiceQR.customerName ?? '',
      customerId: invoiceQR.customerId ?? '',
      originalData: invoiceQR.toJson(),
    );
  }

  factory QRScanData.fromJson(Map<String, dynamic> json) {
    return QRScanData(
      rawData: jsonEncode(json),
      documentType: json['type']?.toString() ?? 'unknown',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      creationDate: json['issueDate'] != null
          ? DateTime.parse(json['issueDate'])
          : null,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      customerName: json['customerName']?.toString() ?? '',
      customerEmail: json['customerEmail']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      originalData: json,
    );
  }

  factory QRScanData.fromFirestore(Map<String, dynamic> data, String type) {
    return QRScanData(
      rawData: jsonEncode(data),
      documentType: type,
      invoiceNumber: data['invoiceNumber']?.toString() ?? data['number']?.toString() ?? '',
      orderId: data['id']?.toString() ?? '',
      creationDate: data['dateCreated'] is Timestamp
          ? (data['dateCreated'] as Timestamp).toDate()
          : null,
      totalAmount: (data['total'] as num?)?.toDouble() ?? 0.0,
      customerName: data['customerName']?.toString() ?? '',
      customerEmail: data['customerEmail']?.toString() ?? '',
      customerPhone: data['customerPhone']?.toString() ?? '',
      originalData: data,
    );
  }
}

class SmartQRScanResult {
  final bool success;
  final String? error;
  final QRScanData? scanData;
  final Map<String, dynamic>? enrichedData;

  SmartQRScanResult.success({
    required this.scanData,
    required this.enrichedData,
  })  : success = true,
        error = null;

  SmartQRScanResult.error(this.error)
      : success = false,
        scanData = null,
        enrichedData = null;

  double get confidenceScore => enrichedData?['confidenceScore'] ?? 0.0;
  DateTime get scannedAt => enrichedData?['scannedAt'] ?? DateTime.now();
}

// Modern QR Scanner Widget for Dashboard
class SmartQRScannerWidget extends StatefulWidget {
  final VoidCallback? onScanComplete;
  final bool showInDashboard;

  const SmartQRScannerWidget({
    super.key,
    this.onScanComplete,
    this.showInDashboard = false,
  });

  @override
  _SmartQRScannerWidgetState createState() => _SmartQRScannerWidgetState();
}

class _SmartQRScannerWidgetState extends State<SmartQRScannerWidget> {
  final SmartQRScanService _scanService = SmartQRScanService();
  bool _isScanning = false;
  SmartQRScanResult? _lastResult;

  void _startSmartScan() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      // Use your existing barcode scanning service
      final scanResult = await BarcodeService.scanBarcode(context);

      if (scanResult.success && scanResult.barcode.isNotEmpty) {
        // Process with smart service
        final smartResult = await _scanService.processQRCode(scanResult.barcode);

        setState(() => _lastResult = smartResult);

        if (smartResult.success) {
          _showSmartResults(smartResult);
        } else {
          _showError(smartResult.error!);
        }
      } else if (scanResult.barcode != '-1') {
        _showError(scanResult.error ?? 'Scan failed');
      }
    } catch (e) {
      _showError('Scanning error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showSmartResults(SmartQRScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartQRResultSheet(
        result: result,
        onPrint: () => _generateAndPrintReport(result),
        onShare: () => _shareReport(result),
      ),
    ).then((_) {
      widget.onScanComplete?.call();
    });
  }

  Future<void> _generateAndPrintReport(SmartQRScanResult result) async {
    try {
      final pdfFile = await _scanService.generateSmartReport(
        result.scanData!,
        result.enrichedData!,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return await pdfFile.readAsBytes();
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report printed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareReport(SmartQRScanResult result) async {
    try {
      final pdfFile = await _scanService.generateSmartReport(
        result.scanData!,
        result.enrichedData!,
      );

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'QR Code Analysis Report - ${result.scanData!.documentType.toUpperCase()}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showInDashboard) {
      return _buildDashboardCard();
    }

    return _buildScannerButton();
  }

  Widget _buildDashboardCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[50]!, Colors.purple[50]!],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart QR Scanner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        'Advanced document analysis & reporting',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Scan any QR code to get intelligent insights, customer history, and professional reports.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startSmartScan,
                icon: _isScanning
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(Icons.qr_code_scanner),
                label: Text(_isScanning ? 'Processing...' : 'Start Smart Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_lastResult != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastResult!.success ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastResult!.success ? Colors.green[200]! : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastResult!.success ? Icons.check_circle : Icons.info,
                      color: _lastResult!.success ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastResult!.success
                            ? 'Last scan: ${_lastResult!.scanData!.documentType}'
                            : 'Last scan failed',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScannerButton() {
    return FloatingActionButton.extended(
      onPressed: _startSmartScan,
      icon: _isScanning
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Icon(Icons.qr_code_scanner),
      label: Text(_isScanning ? 'Scanning...' : 'Smart Scan'),
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      elevation: 4,
    );
  }
}

// Modern Results Sheet
class SmartQRResultSheet extends StatelessWidget {
  final SmartQRScanResult result;
  final VoidCallback onPrint;
  final VoidCallback onShare;

  const SmartQRResultSheet({
    super.key,
    required this.result,
    required this.onPrint,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final scanData = result.scanData!;
    final enrichedData = result.enrichedData!;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 20),

          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTypeColor(scanData.documentType),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getTypeIcon(scanData.documentType),
                    color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scanData.documentType.toUpperCase()} ANALYSIS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Confidence: ${(result.confidenceScore * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Key Information
          _buildInfoSection(scanData),
          SizedBox(height: 20),

          // Customer Insights
          if (enrichedData['customerHistory'] != null)
            _buildCustomerSection(enrichedData['customerHistory']),

          // Analytics
          _buildAnalyticsSection(enrichedData['analytics']),

          // Action Buttons
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: Icon(Icons.share, size: 18),
                  label: Text('Share Report'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrint,
                  icon: Icon(Icons.print, size: 18),
                  label: Text('Print Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoSection(QRScanData data) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOCUMENT INFORMATION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          ..._buildInfoRows(data),
        ],
      ),
    );
  }

  List<Widget> _buildInfoRows(QRScanData data) {
    final rows = <Widget>[];

    if (data.invoiceNumber.isNotEmpty) {
      rows.add(_buildInfoRow('Invoice', data.invoiceNumber));
    }
    if (data.orderId.isNotEmpty) {
      rows.add(_buildInfoRow('Order ID', data.orderId));
    }
    if (data.creationDate != null) {
      rows.add(_buildInfoRow(
        'Date',
        DateFormat('MMM dd, yyyy').format(data.creationDate!),
      ));
    }
    if (data.totalAmount > 0) {
      rows.add(_buildInfoRow(
        'Amount',
        '${Constants.CURRENCY_NAME}${data.totalAmount.toStringAsFixed(2)}',
      ));
    }
    if (data.customerName.isNotEmpty) {
      rows.add(_buildInfoRow('Customer', data.customerName));
    }

    return rows;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(Map<String, dynamic> history) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CUSTOMER INSIGHTS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          SizedBox(height: 12),
          _buildCustomerRow('Total Orders', history['totalOrders'].toString()),
          _buildCustomerRow(
            'Lifetime Value',
            '${Constants.CURRENCY_NAME}${(history['totalSpent'] as double).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(Map<String, dynamic> analytics) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ANALYTICS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.purple[700],
            ),
          ),
          SizedBox(height: 12),
          if (analytics['valueCategory'] != null)
            _buildAnalyticsRow('Value Category', analytics['valueCategory']),
          if (analytics['daysSinceCreation'] != null)
            _buildAnalyticsRow('Document Age', '${analytics['daysSinceCreation']} days'),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'order': return Colors.blue;
      case 'invoice': return Colors.green;
      case 'return': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'order': return Icons.shopping_cart;
      case 'invoice': return Icons.receipt;
      case 'return': return Icons.assignment_return;
      default: return Icons.description;
    }
  }
}
