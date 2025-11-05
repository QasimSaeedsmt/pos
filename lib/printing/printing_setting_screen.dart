import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../features/customerBase/customer_base.dart';
import '../features/orderBase/order_base.dart';
import 'invoice_model.dart';
import 'invoice_preview_screen.dart';
import 'invoice_service.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  _InvoiceSettingsScreenState createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final Map<String, dynamic> _businessInfo = {};
  final Map<String, dynamic> _invoiceSettings = {};
  final Map<String, dynamic> _printerSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _businessInfo.addAll({
        'name': prefs.getString('business_name') ?? 'Your Business Name',
        'address': prefs.getString('business_address') ?? '',
        'phone': prefs.getString('business_phone') ?? '',
        'email': prefs.getString('business_email') ?? '',
        'website': prefs.getString('business_website') ?? '',
        'tagline': prefs.getString('business_tagline') ?? '',
        'taxNumber': prefs.getString('business_tax_number') ?? '',
      });

      _invoiceSettings.addAll({
        'defaultTemplate': prefs.getString('default_invoice_template') ?? 'traditional',
        'taxRate': prefs.getDouble('tax_rate') ?? 0.0,
        'discountRate': prefs.getDouble('discount_rate') ?? 0.0,
        'autoPrint': prefs.getBool('auto_print') ?? false,
        'includeCustomerDetails': prefs.getBool('include_customer_details') ?? true,
        'defaultNotes': prefs.getString('default_notes') ?? 'Thank you for your business!',
      });

      _printerSettings.addAll({
        'printerType': prefs.getString('printer_type') ?? 'thermal',
        'paperWidth': prefs.getInt('paper_width') ?? 80,
        'printerAddress': prefs.getString('printer_address') ?? '',
        'copies': prefs.getInt('print_copies') ?? 1,
      });

      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Save business info
    await prefs.setString('business_name', _businessInfo['name'] ?? '');
    await prefs.setString('business_address', _businessInfo['address'] ?? '');
    await prefs.setString('business_phone', _businessInfo['phone'] ?? '');
    await prefs.setString('business_email', _businessInfo['email'] ?? '');
    await prefs.setString('business_website', _businessInfo['website'] ?? '');
    await prefs.setString('business_tagline', _businessInfo['tagline'] ?? '');
    await prefs.setString('business_tax_number', _businessInfo['taxNumber'] ?? '');

    // Save invoice settings
    await prefs.setString('default_invoice_template', _invoiceSettings['defaultTemplate'] ?? 'traditional');
    await prefs.setDouble('tax_rate', _invoiceSettings['taxRate'] ?? 0.0);
    await prefs.setDouble('discount_rate', _invoiceSettings['discountRate'] ?? 0.0);
    await prefs.setBool('auto_print', _invoiceSettings['autoPrint'] ?? false);
    await prefs.setBool('include_customer_details', _invoiceSettings['includeCustomerDetails'] ?? true);
    await prefs.setString('default_notes', _invoiceSettings['defaultNotes'] ?? '');

    // Save printer settings
    await prefs.setString('printer_type', _printerSettings['printerType'] ?? 'thermal');
    await prefs.setInt('paper_width', _printerSettings['paperWidth'] ?? 80);
    await prefs.setString('printer_address', _printerSettings['printerAddress'] ?? '');
    await prefs.setInt('print_copies', _printerSettings['copies'] ?? 1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green),
    );
  }

  void _testPrint() async {
    // Create a test invoice
    final testOrder = AppOrder(
      id: 'test',
      number: 'TEST-001',
      dateCreated: DateTime.now(),
      total: 150.00,
      lineItems: [
        {
          'productName': 'Test Product 1',
          'productSku': 'TEST001',
          'quantity': 2,
          'price': 50.00,
        },
        {
          'productName': 'Test Product 2',
          'productSku': 'TEST002',
          'quantity': 1,
          'price': 50.00,
        }
      ],
    );

    final testCustomer = Customer(
      id: 'test',
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      phone: '+1234567890',
    );

    final testInvoice = Invoice.fromOrder(
      testOrder,
      testCustomer,
      _businessInfo,
      _invoiceSettings,
      templateType: _invoiceSettings['defaultTemplate'] ?? 'traditional',
    );

    await InvoiceService().printInvoice(testInvoice);
  }

  void _previewInvoice() async {
    final testOrder = AppOrder(
      id: 'test',
      number: 'TEST-001',
      dateCreated: DateTime.now(),
      total: 150.00,
      lineItems: [
        {
          'productName': 'Test Product 1',
          'productSku': 'TEST001',
          'quantity': 2,
          'price': 50.00,
        },
        {
          'productName': 'Test Product 2',
          'productSku': 'TEST002',
          'quantity': 1,
          'price': 50.00,
        }
      ],
    );

    final testCustomer = Customer(
      id: 'test',
      firstName: 'John',
      lastName: 'Doe',
      email: 'john.doe@example.com',
      phone: '+1234567890',
    );

    final testInvoice = Invoice.fromOrder(
      testOrder,
      testCustomer,
      _businessInfo,
      _invoiceSettings,
      templateType: _invoiceSettings['defaultTemplate'] ?? 'traditional',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoicePreviewScreen(invoice: testInvoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice & Printing Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _testPrint,
            tooltip: 'Test Print',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Business Information Section
            _buildSectionHeader('Business Information', Icons.business),
            _buildBusinessInfoSection(),
            SizedBox(height: 24),

            // Invoice Settings Section
            _buildSectionHeader('Invoice Settings', Icons.receipt),
            _buildInvoiceSettingsSection(),
            SizedBox(height: 24),

            // Printer Settings Section
            _buildSectionHeader('Printing Settings', Icons.print),
            _buildPrinterSettingsSection(),
            SizedBox(height: 24),

            // Preview and Test Section
            _buildSectionHeader('Preview & Test', Icons.visibility),
            _buildPreviewSection(),
            SizedBox(height: 32),

            // Save Button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBusinessInfoSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              label: 'Business Name *',
              value: _businessInfo['name'] ?? '',
              onChanged: (value) => _businessInfo['name'] = value,
              icon: Icons.business,
            ),
            _buildTextField(
              label: 'Address',
              value: _businessInfo['address'] ?? '',
              onChanged: (value) => _businessInfo['address'] = value,
              icon: Icons.location_on,
              maxLines: 2,
            ),
            _buildTextField(
              label: 'Phone',
              value: _businessInfo['phone'] ?? '',
              onChanged: (value) => _businessInfo['phone'] = value,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              label: 'Email',
              value: _businessInfo['email'] ?? '',
              onChanged: (value) => _businessInfo['email'] = value,
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            _buildTextField(
              label: 'Website',
              value: _businessInfo['website'] ?? '',
              onChanged: (value) => _businessInfo['website'] = value,
              icon: Icons.language,
            ),
            _buildTextField(
              label: 'Tagline',
              value: _businessInfo['tagline'] ?? '',
              onChanged: (value) => _businessInfo['tagline'] = value,
              icon: Icons.tag,
            ),
            _buildTextField(
              label: 'Tax Number',
              value: _businessInfo['taxNumber'] ?? '',
              onChanged: (value) => _businessInfo['taxNumber'] = value,
              icon: Icons.numbers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSettingsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Default Template
            _buildDropdown(
              label: 'Default Invoice Template',
              value: _invoiceSettings['defaultTemplate'] ?? 'traditional',
              items: [
                DropdownMenuItem(value: 'traditional', child: Text('Traditional A4')),
                DropdownMenuItem(value: 'thermal', child: Text('Thermal Receipt')),
              ],
              onChanged: (value) => setState(() => _invoiceSettings['defaultTemplate'] = value),
              icon: Icons.format_shapes,
            ),

            // Tax Rate
            _buildNumberField(
              label: 'Tax Rate (%)',
              value: _invoiceSettings['taxRate'] ?? 0.0,
              onChanged: (value) => _invoiceSettings['taxRate'] = value,
              icon: Icons.percent,
            ),

            // Discount Rate
            _buildNumberField(
              label: 'Default Discount Rate (%)',
              value: _invoiceSettings['discountRate'] ?? 0.0,
              onChanged: (value) => _invoiceSettings['discountRate'] = value,
              icon: Icons.discount,
            ),

            // Default Notes
            _buildTextField(
              label: 'Default Invoice Notes',
              value: _invoiceSettings['defaultNotes'] ?? '',
              onChanged: (value) => _invoiceSettings['defaultNotes'] = value,
              icon: Icons.note,
              maxLines: 3,
            ),

            // Toggle Settings
            _buildToggle(
              label: 'Auto Print After Sale',
              value: _invoiceSettings['autoPrint'] ?? false,
              onChanged: (value) => setState(() => _invoiceSettings['autoPrint'] = value),
              icon: Icons.print,
            ),

            _buildToggle(
              label: 'Include Customer Details',
              value: _invoiceSettings['includeCustomerDetails'] ?? true,
              onChanged: (value) => setState(() => _invoiceSettings['includeCustomerDetails'] = value),
              icon: Icons.person,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterSettingsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Printer Type
            _buildDropdown(
              label: 'Printer Type',
              value: _printerSettings['printerType'] ?? 'thermal',
              items: [
                DropdownMenuItem(value: 'thermal', child: Text('Thermal Printer')),
                DropdownMenuItem(value: 'a4', child: Text('A4 Printer')),
                DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth Printer')),
                DropdownMenuItem(value: 'network', child: Text('Network Printer')),
              ],
              onChanged: (value) => setState(() => _printerSettings['printerType'] = value),
              icon: Icons.print,
            ),

            if (_printerSettings['printerType'] == 'thermal')
              _buildDropdown(
                label: 'Paper Width',
                value: _printerSettings['paperWidth'] ?? 80,
                items: [
                  DropdownMenuItem(value: 58, child: Text('58mm (2.3")')),
                  DropdownMenuItem(value: 80, child: Text('80mm (3.1")')),
                ],
                onChanged: (value) => setState(() => _printerSettings['paperWidth'] = value),
                icon: Icons.straighten,
              ),

            if (['network', 'bluetooth'].contains(_printerSettings['printerType']))
              _buildTextField(
                label: 'Printer Address',
                value: _printerSettings['printerAddress'] ?? '',
                onChanged: (value) => _printerSettings['printerAddress'] = value,
                icon: Icons.wifi,
                hintText: _printerSettings['printerType'] == 'network'
                    ? 'IP Address: 192.168.1.100'
                    : 'Bluetooth MAC Address',
              ),

            _buildNumberField(
              label: 'Number of Copies',
              value: (_printerSettings['copies'] ?? 1).toDouble(),
              onChanged: (value) => _printerSettings['copies'] = value.toInt(),
              icon: Icons.copy,
              min: 1,
              max: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Preview your invoice with current settings',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _previewInvoice,
                    icon: Icon(Icons.visibility),
                    label: Text('Preview Invoice'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testPrint,
                    icon: Icon(Icons.print),
                    label: Text('Test Print'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _saveSettings,
        icon: Icon(Icons.save),
        label: Text(
          'SAVE ALL SETTINGS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required Function(String) onChanged,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(),
          hintText: hintText,
        ),
        controller: TextEditingController(text: value),
        onChanged: onChanged,
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required Function(double) onChanged,
    required IconData icon,
    double min = 0,
    double max = 100,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(),
          suffixText: '%',
        ),
        controller: TextEditingController(text: value.toStringAsFixed(2)),
        onChanged: (text) {
          final newValue = double.tryParse(text) ?? min;
          if (newValue >= min && newValue <= max) {
            onChanged(newValue);
          }
        },
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(child: Text(label)),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}