// Scanning Settings Screen - Dedicated for default scanning preferences
import 'package:flutter/material.dart';

import '../invoiceBase/invoice_and_printing_base.dart';

class ScanningSettingsScreen extends StatefulWidget {
  const ScanningSettingsScreen({super.key});

  @override
  _ScanningSettingsScreenState createState() => _ScanningSettingsScreenState();
}

class _ScanningSettingsScreenState extends State<ScanningSettingsScreen> {
  bool _isDefaultEnabled = false;
  ScanningOption? _currentDefaultOption;
  List<String> _recentBarcodes = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isEnabled = await ScanningPreferencesService.isDefaultEnabled();
    final defaultOption = await ScanningPreferencesService.getDefaultScanningOption();
    final recentBarcodes = await ScanningPreferencesService.getRecentBarcodes();

    if (mounted) {
      setState(() {
        _isDefaultEnabled = isEnabled;
        _currentDefaultOption = defaultOption;
        _recentBarcodes = recentBarcodes;
      });
    }
  }

  Future<void> _toggleDefaultScanning(bool value) async {
    await ScanningPreferencesService.setDefaultEnabled(value);
    setState(() {
      _isDefaultEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Default scanning enabled' : 'Default scanning disabled',
        ),
        backgroundColor: value ? Colors.green : Colors.blue,
      ),
    );
  }

  Future<void> _setDefaultOption(ScanningOption option) async {
    await ScanningPreferencesService.setDefaultScanningOption(option);
    await ScanningPreferencesService.setDefaultEnabled(true);

    setState(() {
      _currentDefaultOption = option;
      _isDefaultEnabled = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Default set to ${option.title}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _clearRecentBarcodes() async {
    await ScanningPreferencesService.clearRecentBarcodes();
    setState(() {
      _recentBarcodes.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recent barcodes cleared'))
    );
  }

  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset All Settings'),
        content: Text('Reset all scanning preferences to default?'),
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
      await ScanningPreferencesService.resetDefaults();
      await ScanningPreferencesService.clearRecentBarcodes();

      setState(() {
        _isDefaultEnabled = false;
        _currentDefaultOption = null;
        _recentBarcodes.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All settings reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildScanningOptionCard(ScanningOption option) {
    final isSelected = _currentDefaultOption == option;
    final isActive = _isDefaultEnabled && isSelected;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: isActive ? Colors.blue[50] : null,
      child: ListTile(
        leading: Icon(
          option.icon,
          color: isActive ? Colors.blue : Colors.grey,
          size: 30,
        ),
        title: Text(
          option.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.blue[800] : null,
          ),
        ),
        subtitle: Text(
          option.subtitle,
          style: TextStyle(
            color: isActive ? Colors.blue[600] : Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Icon(Icons.check_circle, color: Colors.green, size: 24),
            if (!isActive)
              IconButton(
                icon: Icon(Icons.star_border, color: Colors.amber),
                onPressed: () => _setDefaultOption(option),
                tooltip: 'Set as Default',
              ),
          ],
        ),
        onTap: () => _setDefaultOption(option),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanning Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Default Scanning Section
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.blue, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Default Scanning',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Default Scanning Toggle
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Default Scanning Method',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            if (_isDefaultEnabled && _currentDefaultOption != null)
                              Text(
                                'Current: ${_currentDefaultOption!.title}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (_isDefaultEnabled && _currentDefaultOption == null)
                              Text(
                                'No default method selected',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isDefaultEnabled,
                        onChanged: _toggleDefaultScanning,activeThumbColor: Colors.blue,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Scanning Options
                  Text(
                    'Select Default Method:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),

                  ...ScanningOption.values.map(_buildScanningOptionCard),

                  if (!_isDefaultEnabled && _currentDefaultOption != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Turn on "Use Default Scanning" to activate ${_currentDefaultOption!.title}',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 14,
                              ),
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

          // Recent Barcodes Section
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: Colors.purple, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Recent Barcodes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  if (_recentBarcodes.isEmpty)
                    Column(
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.grey[400]),
                        SizedBox(height: 8),
                        Text(
                          'No recent barcodes',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Scanned barcodes will appear here for quick access',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recently scanned barcodes:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 12),

                        Container(
                          constraints: BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _recentBarcodes.map((barcode) {
                                return Chip(
                                  label: Text(
                                    barcode,
                                    style: TextStyle(
                                      fontFamily: 'Monospace',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: Colors.grey[100],
                                  deleteIcon: Icon(Icons.clear, size: 16),
                                  onDeleted: () {
                                    // Individual deletion could be implemented here
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _clearRecentBarcodes,
                          icon: Icon(Icons.clear_all, size: 18),
                          label: Text('Clear All Recent Barcodes'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  Text(
                    'Reset all scanning preferences to their default values. '
                        'This will clear your default scanning method and recent barcodes.',
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
                      label: Text('Reset All Scanning Settings'),
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

          SizedBox(height: 24),

          // Quick Test Section
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Your Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Test your default scanning configuration:',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await UniversalScanningService.scanBarcode(context);
                      if (result != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Scanned: $result'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Test Scanning'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}