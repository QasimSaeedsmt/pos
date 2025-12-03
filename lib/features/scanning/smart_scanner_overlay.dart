// Invoice Settings Screen
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Invoice Settings Screen

// Invoice Settings Screen


// Invoice Settings Screen

class NewInvoiceSettingsScreen extends StatefulWidget {
  const NewInvoiceSettingsScreen({super.key});

  @override
  _NewInvoiceSettingsScreenState createState() => _NewInvoiceSettingsScreenState();
}

class _NewInvoiceSettingsScreenState extends State<NewInvoiceSettingsScreen> {
  String _selectedTemplate = 'traditional';
  bool _autoPrint = false;
  double _taxRate = 0.0;
  double _discountRate = 0.0;
  bool _includeCustomerDetails = true;
  String _defaultNotes = 'Thank you for your business!';
  String _printerSelection = 'default';

  // Business Info
  String _businessName = '';
  String _businessAddress = '';
  String _businessPhone = '';
  String _businessEmail = '';
  String _businessWebsite = '';
  String _businessTagline = '';
  String _businessTaxNumber = '';

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
      _taxRate = prefs.getDouble('tax_rate') ?? 0.0;
      _discountRate = prefs.getDouble('discount_rate') ?? 0.0;
      _includeCustomerDetails = prefs.getBool('include_customer_details') ?? true;
      _defaultNotes = prefs.getString('default_notes') ?? 'Thank you for your business!';
      _printerSelection = prefs.getString('printer_selection') ?? 'default';

      // Business Info
      _businessName = prefs.getString('business_name') ?? '';
      _businessAddress = prefs.getString('business_address') ?? '';
      _businessPhone = prefs.getString('business_phone') ?? '';
      _businessEmail = prefs.getString('business_email') ?? '';
      _businessWebsite = prefs.getString('business_website') ?? '';
      _businessTagline = prefs.getString('business_tagline') ?? '';
      _businessTaxNumber = prefs.getString('business_tax_number') ?? '';
    });
  }

  Future<void> _saveTemplate(String template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_invoice_template', template);
    setState(() {
      _selectedTemplate = template;
    });
  }

  Future<void> _saveAutoPrint(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_print', value);
    setState(() {
      _autoPrint = value;
    });
  }

  Future<void> _saveTaxRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tax_rate', value);
    setState(() {
      _taxRate = value;
    });
  }

  Future<void> _saveDiscountRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('discount_rate', value);
    setState(() {
      _discountRate = value;
    });
  }

  Future<void> _saveCustomerDetails(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('include_customer_details', value);
    setState(() {
      _includeCustomerDetails = value;
    });
  }

  Future<void> _saveDefaultNotes(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_notes', value);
    setState(() {
      _defaultNotes = value;
    });
  }

  Future<void> _savePrinterSelection(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_selection', value);
    setState(() {
      _printerSelection = value;
    });
  }

  // Business Info Save Methods
  Future<void> _saveBusinessName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_name', value);
    setState(() {
      _businessName = value;
    });
  }

  Future<void> _saveBusinessAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_address', value);
    setState(() {
      _businessAddress = value;
    });
  }

  Future<void> _saveBusinessPhone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_phone', value);
    setState(() {
      _businessPhone = value;
    });
  }

  Future<void> _saveBusinessEmail(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_email', value);
    setState(() {
      _businessEmail = value;
    });
  }

  Future<void> _saveBusinessWebsite(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_website', value);
    setState(() {
      _businessWebsite = value;
    });
  }

  Future<void> _saveBusinessTagline(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_tagline', value);
    setState(() {
      _businessTagline = value;
    });
  }

  Future<void> _saveBusinessTaxNumber(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_tax_number', value);
    setState(() {
      _businessTaxNumber = value;
    });
  }

  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset All Settings'),
        content: Text('Reset all invoice settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('default_invoice_template');
      await prefs.remove('auto_print');
      await prefs.remove('tax_rate');
      await prefs.remove('discount_rate');
      await prefs.remove('include_customer_details');
      await prefs.remove('default_notes');
      await prefs.remove('printer_selection');

      await _loadSettings(); // Reload to get default values

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All settings reset to default'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
      onSelected: (selected) => _saveTemplate(value),
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[800] : Colors.grey[800],
      ),
    );
  }

  Widget _buildPrinterOption(String label, String value, String description) {
    final isSelected = _printerSelection == value;
    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? Colors.blue[50] : Colors.grey[50],
      child: RadioListTile<String>(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue[800] : Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        value: value,
        groupValue: _printerSelection,
        onChanged: (value) => _savePrinterSelection(value!),
        secondary: Icon(Icons.print, color: isSelected ? Colors.blue : Colors.grey),
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            _buildEditableField(
              'Business Name',
              _businessName,
              Icons.store,
              _saveBusinessName,
            ),
            _buildEditableField(
              'Address',
              _businessAddress,
              Icons.location_on,
              _saveBusinessAddress,
            ),
            _buildEditableField(
              'Phone',
              _businessPhone,
              Icons.phone,
              _saveBusinessPhone,
            ),
            _buildEditableField(
              'Email',
              _businessEmail,
              Icons.email,
              _saveBusinessEmail,
            ),
            _buildEditableField(
              'Website',
              _businessWebsite,
              Icons.language,
              _saveBusinessWebsite,
            ),
            _buildEditableField(
              'Tagline',
              _businessTagline,
              Icons.tag,
              _saveBusinessTagline,
            ),
            _buildEditableField(
              'Tax Number',
              _businessTaxNumber,
              Icons.numbers,
              _saveBusinessTaxNumber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, String value, IconData icon, Function(String) onSave) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                InkWell(
                  onTap: () => _showEditDialog(label, value, onSave),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            value.isEmpty ? 'Tap to set $label' : value,
                            style: TextStyle(
                              color: value.isEmpty ? Colors.grey[500] : Colors.black,
                            ),
                          ),
                        ),
                        Icon(Icons.edit, size: 16, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String label, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: OutlineInputBorder(),
          ),
          maxLines: label == 'Address' ? 3 : 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Business Information
            _buildBusinessInfoSection(),
            SizedBox(height: 16),
        
            // Template Settings
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.green, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Invoice Template',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
        
                    Text(
                      'Default Template:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildTemplateOption('Traditional A4', 'traditional', Icons.description),
                        _buildTemplateOption('Thermal Receipt', 'thermal', Icons.receipt),
                        _buildTemplateOption('Ask Every Time', 'ask', Icons.help_outline),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
        
            // Print Settings
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.print, color: Colors.orange, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Print Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
        
                    Row(
                      children: [
                        Icon(Icons.print, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Expanded(child: Text('Auto Print After Generation')),
                        Switch(
                          value: _autoPrint,
                          onChanged: _saveAutoPrint,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
        
                    // Printer Selection
                    Text(
                      'Printer Selection:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
        
                    _buildPrinterOption(
                      'Use Default Printer',
                      'default',
                      'Always use the system default printer',
                    ),
                    SizedBox(height: 8),
        
                    _buildPrinterOption(
                      'Ask Every Time',
                      'ask',
                      'Show printer selection dialog before printing',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
        
            // Invoice Content
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: Colors.purple, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Invoice Content',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
        
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Expanded(child: Text('Include Customer Details')),
                        Switch(
                          value: _includeCustomerDetails,
                          onChanged: _saveCustomerDetails,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
        
                    _buildEditableField(
                      'Default Notes',
                      _defaultNotes,
                      Icons.note,
                      _saveDefaultNotes,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
        
            // Tax & Discount Rates
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.percent, color: Colors.red, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Tax & Discount Rates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
        
                    _buildRateSlider(
                      'Tax Rate',
                      _taxRate,
                      Icons.receipt_long,
                      _saveTaxRate,
                    ),
                    SizedBox(height: 16),
        
                    _buildRateSlider(
                      'Discount Rate',
                      _discountRate,
                      Icons.discount,
                      _saveDiscountRate,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
        
            // Reset Section
            Card(
              elevation: 2,
              color: Colors.orange[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings_backup_restore, color: Colors.orange, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Reset Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
        
                    Text(
                      'Reset all invoice settings to default values. This will clear your business information, template preferences, and other settings.',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 14,
                      ),
                    ),
        
                    SizedBox(height: 16),
        
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resetAllSettings,
                        icon: Icon(Icons.restore, size: 20),
                        label: Text('Reset All Invoice Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateSlider(String label, double value, IconData icon, Function(double) onSave) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            SizedBox(width: 12),
            Text(
              '$label: ${(value * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: 8),
        Slider(
          value: value,
          min: 0.0,
          max: 0.5, // 50% maximum
          divisions: 50,
          label: '${(value * 100).toStringAsFixed(1)}%',
          onChanged: (newValue) => onSave(newValue),
        ),
      ],
    );
  }
}