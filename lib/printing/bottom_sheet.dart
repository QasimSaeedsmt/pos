import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../constants.dart';
import '../features/customerBase/customer_base.dart';
import '../features/orderBase/order_base.dart';
import 'invoice_model.dart';
import 'invoice_service.dart';

class InvoiceOptionsBottomSheetWithNoOptions extends StatelessWidget {
  final AppOrder order;
  final Customer? customer;
  final Map<String, dynamic> businessInfo;
  final Map<String, dynamic> invoiceSettings;

  const InvoiceOptionsBottomSheetWithNoOptions({
    super.key,
    required this.order,
    this.customer,
    required this.businessInfo,
    required this.invoiceSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order Completed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Order #${order.number} has been processed successfully',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Total: ${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 24),

            // Invoice Options
            if (invoiceSettings['autoPrint'] ?? false)
              ListTile(
                leading: Icon(Icons.print, color: Colors.blue),
                title: Text('Auto-printing invoice...'),
                trailing: CircularProgressIndicator(),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Generate and print invoice
                        _printInvoice(context);
                      },
                      icon: Icon(Icons.print),
                      label: Text('Print Invoice'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.done),
                      label: Text('Continue'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _printInvoice(BuildContext context) {
    // Use business info and invoice settings for printing
    final invoice = Invoice.fromOrder(
      order,
      customer,
      businessInfo,
      invoiceSettings,
      templateType: invoiceSettings['defaultTemplate'] ?? 'traditional',
    );

    // Print the invoice
    InvoiceService().printInvoice(invoice);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Invoice sent to printer')));

    Navigator.pop(context);
  }
}


class InvoiceOptionsBottomSheetWithOptions extends StatefulWidget {
  final AppOrder order;
  final Customer? customer;
  final Map<String, dynamic>? enhancedData;

  const InvoiceOptionsBottomSheetWithOptions({
    super.key,
    required this.order,
    this.customer,
    this.enhancedData,
  });

  @override
  _InvoiceOptionsBottomSheetWithOptionsState createState() => _InvoiceOptionsBottomSheetWithOptionsState();
}

class _InvoiceOptionsBottomSheetWithOptionsState extends State<InvoiceOptionsBottomSheetWithOptions> {
  String _selectedTemplate = 'traditional';
  bool _autoPrint = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTemplate = prefs.getString('default_invoice_template') ?? 'traditional';
      _autoPrint = prefs.getBool('auto_print') ?? false;
    });
  }

  Future<Map<String, dynamic>> _getBusinessInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('business_name') ?? 'Your Business Name',
      'address': prefs.getString('business_address') ?? '',
      'phone': prefs.getString('business_phone') ?? '',
      'email': prefs.getString('business_email') ?? '',
      'website': prefs.getString('business_website') ?? '',
      'tagline': prefs.getString('business_tagline') ?? '',
      'taxNumber': prefs.getString('business_tax_number') ?? '',
    };
  }

  Future<Map<String, dynamic>> _getInvoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'defaultTemplate': prefs.getString('default_invoice_template') ?? 'traditional',
      'taxRate': prefs.getDouble('tax_rate') ?? 0.0,
      'discountRate': prefs.getDouble('discount_rate') ?? 0.0,
      'autoPrint': prefs.getBool('auto_print') ?? false,
      'includeCustomerDetails': prefs.getBool('include_customer_details') ?? true,
      'defaultNotes': prefs.getString('default_notes') ?? 'Thank you for your business!',
    };
  }

  void _generateInvoice() async {
    final businessInfo = await _getBusinessInfo();
    final invoiceSettings = await _getInvoiceSettings();

    // Use enhanced invoice creation if enhanced data is available
    final invoice = widget.enhancedData != null
        ? Invoice.fromEnhancedOrder(
      widget.order,
      widget.customer,
      businessInfo,
      invoiceSettings,
      templateType: _selectedTemplate,
      enhancedData: widget.enhancedData,
    )
        : Invoice.fromOrder(
      widget.order,
      widget.customer,
      businessInfo,
      invoiceSettings,
      templateType: _selectedTemplate,
    );

    // Generate PDF
    final pdfFile = await InvoiceService().generatePdfInvoice(invoice);

    // Auto print if enabled
    if (_autoPrint) {
      await InvoiceService().printInvoice(invoice);
    }

    // Show success dialog with options
    _showSuccessDialog(invoice, pdfFile);
  }

  void _showSuccessDialog(Invoice invoice, File pdfFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice Generated'),
        content: Text('Invoice ${invoice.invoiceNumber} has been generated successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              InvoiceService().printInvoice(invoice);
            },
            child: Text('Print'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              InvoiceService().shareInvoice(invoice);
            },
            child: Text('Share/Export'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Generate Invoice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Enhanced Data Indicator
            if (widget.enhancedData != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.discount, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enhanced pricing data available',
                          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Template Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice Template', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildTemplateOption('Traditional A4', 'traditional', Icons.description),
                        _buildTemplateOption('Thermal Receipt', 'thermal', Icons.receipt),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Auto Print Option
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(child: Text('Auto Print After Generation')),
                    Switch(
                      value: _autoPrint,
                      onChanged: (value) => setState(() => _autoPrint = value),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Skip'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateInvoice,
                    icon: Icon(Icons.receipt_long),
                    label: Text('Generate Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateOption(String label, String value, IconData icon) {
    final isSelected = _selectedTemplate == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedTemplate = value),
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[800] : Colors.grey[800],
      ),
    );
  }
}
