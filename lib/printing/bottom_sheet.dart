import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../core/models/app_order_model.dart';
import '../core/models/customer_model.dart';
import '../features/credit/credit_sale_model.dart';
import '../features/users/users_base.dart';
import 'invoice_model.dart';
import 'invoice_service.dart';

class InvoiceOptionsBottomSheetWithOptions extends StatefulWidget {
  final AppOrder order;
  final Customer? customer;
  final Map<String, dynamic>? enhancedData;
  final CreditSaleData? creditSaleData;
  final AppUser? currentUser; // Add this


  const InvoiceOptionsBottomSheetWithOptions({
    super.key,
    required this.order,
    this.customer,
    this.enhancedData,
    this.creditSaleData,
    this.currentUser, // Add this

  });

  @override
  _InvoiceOptionsBottomSheetWithOptionsState createState() => _InvoiceOptionsBottomSheetWithOptionsState();
}

class _InvoiceOptionsBottomSheetWithOptionsState extends State<InvoiceOptionsBottomSheetWithOptions> {
  String _selectedTemplate = 'traditional';
  bool _autoPrint = false;
  String _printerSelection = 'default';

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
      _printerSelection = prefs.getString('printer_selection') ?? 'default';
    });
  }

  Future<Map<String, dynamic>> _getBusinessInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('business_name') ?? '',
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
      'printerSelection': prefs.getString('printer_selection') ?? 'default',
    };
  }

  void _generateInvoice() async {
    final businessInfo = await _getBusinessInfo();
    final invoiceSettings = await _getInvoiceSettings();

    final templateToUse = _selectedTemplate == 'ask' ? 'traditional' : _selectedTemplate;

    final invoice = widget.enhancedData != null
        ? Invoice.fromEnhancedOrder(
      widget.order,
      widget.customer,
      businessInfo,
      invoiceSettings,
      templateType: templateToUse,
      enhancedData: widget.enhancedData,
      creditSaleData: widget.creditSaleData,
      printedBy: widget.currentUser?.formattedName,
    )
        : Invoice.fromOrder(
      widget.order,
      widget.customer,
      businessInfo,
      invoiceSettings,
      templateType: templateToUse,
      creditSaleData: widget.creditSaleData,
      printedBy: widget.currentUser?.formattedName,
    );

    // Make sure currentUser is passed here
    final pdfFile = await InvoiceService().generatePdfInvoice(
        invoice,
        currentUser: widget.currentUser // This was missing
    );

    if (_autoPrint) {
      await _handlePrinting(invoice, currentUser: widget.currentUser);
    }
    _showSuccessDialog(invoice, pdfFile);

  }


  Future<void> _handlePrinting(Invoice invoice, {AppUser? currentUser}) async {
    if (_printerSelection == 'ask') {
      final selectedPrinter = await _showPrinterSelectionDialog();
      if (selectedPrinter != null) {
        await InvoiceService().printInvoice(
            invoice,
            printer: selectedPrinter,
            currentUser: currentUser // Add this
        );
      }
    } else {
      // Use default printer - make sure currentUser is passed
      await InvoiceService().printInvoice(
          invoice,
          currentUser: currentUser // Add this
      );
    }
  }
  Future<String?> _showPrinterSelectionDialog() async {
    // In a real app, you would get actual printers from a printing plugin
    final availablePrinters = await _getAvailablePrinters();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Printer'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availablePrinters.length,
            itemBuilder: (context, index) {
              final printer = availablePrinters[index];
              return ListTile(
                leading: Icon(Icons.print),
                title: Text(printer),
                onTap: () => Navigator.of(context).pop(printer),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _getAvailablePrinters() async {
    // Mock implementation - replace with actual printer discovery
    await Future.delayed(Duration(milliseconds: 300));
    return [
      'Default Printer',
      'Office HP LaserJet',
      'Receipt Printer Epson',
      'PDF Printer'
    ];
  }

  void _showSuccessDialog(Invoice invoice, File pdfFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invoice ${invoice.invoiceNumber} has been generated successfully.'),
            if (invoice.showCreditDetails) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    Text(
                      'Credit Sale Invoice',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Credit Amount: ${Constants.CURRENCY_NAME}${invoice.creditAmount!.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (invoice.hasPartialPayment)
                      Text(
                        'Paid: ${Constants.CURRENCY_NAME}${invoice.paidAmount!.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handlePrinting(invoice);
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

  Widget _buildTemplateSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getInvoiceSettings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        final settings = snapshot.data!;
        final defaultTemplate = settings['defaultTemplate'] ?? 'traditional';

        // If default template is "ask", show template selection options
        if (defaultTemplate == 'ask') {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Template', style: TextStyle(fontWeight: FontWeight.bold)),
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
          );
        } else {
          // Show the current template being used
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Template',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          defaultTemplate == 'traditional' ? 'Traditional A4' : 'Thermal Receipt',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check, color: Colors.green),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildPrintSettingsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getInvoiceSettings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        final settings = snapshot.data!;
        final autoPrint = settings['autoPrint'] ?? false;
        final printerSelection = settings['printerSelection'] ?? 'default';

        return Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto Print', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            autoPrint ? 'Enabled' : 'Disabled',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoPrint,
                      onChanged: (value) => setState(() => _autoPrint = value),
                    ),
                  ],
                ),
              ),
            ),
            if (autoPrint) ...[
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Printer Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              printerSelection == 'default'
                                  ? 'Default Printer'
                                  : 'Ask Every Time',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCreditData = widget.creditSaleData?.isCreditSale ?? false;
    final hasEnhancedData = widget.enhancedData != null;

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

            if (hasCreditData || hasEnhancedData)
              Card(
                color: hasCreditData ? Colors.orange[50] : Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        hasCreditData ? Icons.credit_card : Icons.discount,
                        color: hasCreditData ? Colors.orange : Colors.green,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasCreditData
                                  ? 'Credit Sale Invoice'
                                  : 'Enhanced Pricing Data',
                              style: TextStyle(
                                color: hasCreditData ? Colors.orange[800] : Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasCreditData && widget.creditSaleData != null)
                              Text(
                                'Credit: ${Constants.CURRENCY_NAME}${widget.creditSaleData!.creditAmount.toStringAsFixed(2)} | Paid: ${Constants.CURRENCY_NAME}${widget.creditSaleData!.paidAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Template Section (shows selection only if "ask every time" is set in settings)
            _buildTemplateSection(),
            SizedBox(height: 16),

            // Print Settings Section
            _buildPrintSettingsSection(),
            SizedBox(height: 16),

            // Business Info Preview
            FutureBuilder<Map<String, dynamic>>(
              future: _getBusinessInfo(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!['name'].isNotEmpty) {
                  return Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.business, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              snapshot.data!['name'],
                              style: TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SizedBox();
              },
            ),

            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
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
                      foregroundColor: Colors.white,
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


