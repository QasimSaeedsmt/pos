// Scanner Overlay
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../printing/invoice_model.dart';
import '../../printing/invoice_service.dart';
import '../barcode/barcode_base.dart';
import '../customerBase/customer_base.dart';
import '../orderBase/order_base.dart';

class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scanAreaSize = size.width * 0.7;
    final scanRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scanAreaSize,
      height: scanAreaSize * 0.6,
    );

    final scanPath = Path()..addRect(scanRect);
    final overlayPath = Path.combine(PathOperation.difference, path, scanPath);

    canvas.drawPath(overlayPath, paint);
    canvas.drawRect(
      scanRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Add this to your main screen navigation
// Enhanced Scanning Preferences Service
class ScanningPreferencesService {
  static const String _defaultScanningOptionKey = 'default_scanning_option';
  static const String _isDefaultEnabledKey = 'is_default_enabled';
  static const String _recentBarcodesKey = 'recent_barcodes';
  static const int _maxRecentBarcodes = 10;

  // Default scanning option methods
  static Future<void> setDefaultScanningOption(ScanningOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultScanningOptionKey, option.name);
  }

  static Future<ScanningOption?> getDefaultScanningOption() async {
    final prefs = await SharedPreferences.getInstance();
    final optionName = prefs.getString(_defaultScanningOptionKey);
    if (optionName == null) return null;

    try {
      return ScanningOption.values.firstWhere(
            (option) => option.name == optionName,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<void> setDefaultEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDefaultEnabledKey, enabled);
  }

  static Future<bool> isDefaultEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDefaultEnabledKey) ?? false;
  }

  static Future<void> resetDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_defaultScanningOptionKey);
    await prefs.remove(_isDefaultEnabledKey);
  }

  // Recent barcodes methods
  static Future<void> addRecentBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> recentBarcodes = await getRecentBarcodes();

    // Remove if already exists (to avoid duplicates)
    recentBarcodes.removeWhere((b) => b == barcode);

    // Add to beginning
    recentBarcodes.insert(0, barcode);

    // Limit the list size
    if (recentBarcodes.length > _maxRecentBarcodes) {
      recentBarcodes = recentBarcodes.sublist(0, _maxRecentBarcodes);
    }

    await prefs.setStringList(_recentBarcodesKey, recentBarcodes);
  }

  static Future<List<String>> getRecentBarcodes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentBarcodesKey) ?? [];
  }

  static Future<void> clearRecentBarcodes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentBarcodesKey);
  }

  // Quick access to check if default scanning is available
  static Future<bool> shouldUseDefaultScanning() async {
    final isEnabled = await isDefaultEnabled();
    final defaultOption = await getDefaultScanningOption();
    return isEnabled && defaultOption != null;
  }
}

// Universal Scanning Service
class UniversalScanningService {
  static Future<String?> scanBarcode(
      BuildContext context, {
        String purpose = 'scan',
      }) async {
    // Check if default scanning is enabled
    final shouldUseDefault =
    await ScanningPreferencesService.shouldUseDefaultScanning();
    final defaultOption =
    await ScanningPreferencesService.getDefaultScanningOption();

    if (shouldUseDefault && defaultOption != null) {
      return await _executeScanningOption(
        context,
        defaultOption,
        purpose: purpose,
      );
    }

    // Show options sheet if no default is set
    return await _showScanningOptionsSheet(context, purpose: purpose);
  }

  static Future<String?> _executeScanningOption(
      BuildContext context,
      ScanningOption option, {
        String purpose = 'scan',
      }) async {
    switch (option) {
      case ScanningOption.camera:
        return await _startCameraBarcodeScan(context, purpose: purpose);
      case ScanningOption.hardware:
        return await _navigateToHardwareScannerScreen(
          context,
          purpose: purpose,
        );
      case ScanningOption.manual:
        return await _showManualBarcodeInput(context, purpose: purpose);
    }
  }

  static Future<String?> _showScanningOptionsSheet(
      BuildContext context, {
        String purpose = 'scan',
      }) async {
    return await showModalBottomSheet<String?>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          _buildUniversalBarcodeOptionsSheet(context, purpose: purpose),
    );
  }

  static Widget _buildUniversalBarcodeOptionsSheet(
      BuildContext context, {
        String purpose = 'scan',
      }) {
    String title;
    switch (purpose) {
      case 'search':
        title = 'Search Product by Barcode';
      case 'restock':
        title = 'Restock Product by Barcode';
      case 'add':
        title = 'Add Product Barcode';
      default:
        title = 'Scan Barcode';
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // Default Option Toggle
          _buildDefaultOptionToggle(context),
          SizedBox(height: 8),

          Divider(),
          SizedBox(height: 8),

          // Recent Barcodes (if any)
          _buildRecentBarcodesSection(context),

          // Scanning Options
          _buildUniversalBarcodeOption(
            context,
            icon: Icons.camera_alt,
            title: 'Camera Scan',
            subtitle: 'Use device camera',
            onTap: () async {
              final result = await _startCameraBarcodeScan(
                context,
                purpose: purpose,
              );
              Navigator.of(context).pop(result);
              return null;
            },
            onSetDefault: () =>
                _setDefaultScanningOption(context, ScanningOption.camera),
          ),
          _buildUniversalBarcodeOption(
            context,
            icon: Icons.keyboard_return,
            title: 'Hardware Scanner',
            subtitle: 'Use a connected barcode scanner',
            onTap: () async {
              final result = await _navigateToHardwareScannerScreen(
                context,
                purpose: purpose,
              );
              Navigator.of(context).pop(result);
              return null;
            },
            onSetDefault: () =>
                _setDefaultScanningOption(context, ScanningOption.hardware),
          ),
          _buildUniversalBarcodeOption(
            context,
            icon: Icons.keyboard,
            title: 'Manual Entry',
            subtitle: 'Type barcode manually',
            onTap: () async {
              final result = await _showManualBarcodeInput(
                context,
                purpose: purpose,
              );
              Navigator.of(context).pop(result);
              return null;
            },
            onSetDefault: () =>
                _setDefaultScanningOption(context, ScanningOption.manual),
          ),

          SizedBox(height: 16),

          // Reset Defaults Button
          _buildResetDefaultsButton(context),
          SizedBox(height: 8),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Camera Scanning
  static Future<String?> _startCameraBarcodeScan(
      BuildContext context, {
        String purpose = 'scan',
      }) async {
    try {
      final result = await BarcodeService.scanBarcode(context);

      if (result.success && result.barcode.isNotEmpty) {
        await ScanningPreferencesService.addRecentBarcode(result.barcode);
        return result.barcode;
      } else if (result.barcode == '-1') {
        // Cancelled
        return null;
      } else {
        _showSnackBar(context, result.error ?? 'Scan failed', Colors.red);
        return null;
      }
    } catch (e) {
      _showSnackBar(context, 'Camera scan failed: $e', Colors.red);
      return null;
    }
  }

  // Hardware Scanner
  static Future<String?> _navigateToHardwareScannerScreen(
      BuildContext context, {
        String purpose = 'scan',
      }) async {
    final scannedCode = await Navigator.of(
      context,
    ).push<String?>(MaterialPageRoute(builder: (_) => HardwareScannerScreen()));

    if (scannedCode != null && scannedCode.isNotEmpty) {
      await ScanningPreferencesService.addRecentBarcode(scannedCode);
    }

    return scannedCode;
  }

  // Manual Input
  static Future<String?> _showManualBarcodeInput(
      BuildContext context, {
        String purpose = 'scan',
      }) async {
    String? barcode = await showDialog<String>(
      context: context,
      builder: (context) => BarcodeManualInputDialog(
        onBarcodeScanned: (barcode) {
          Navigator.of(context).pop(barcode);
        },
      ),
    );

    if (barcode != null && barcode.isNotEmpty) {
      await ScanningPreferencesService.addRecentBarcode(barcode);
    }

    return barcode;
  }

  // UI Components (similar to previous implementation but static)
  static Widget _buildDefaultOptionToggle(BuildContext context) {
    return FutureBuilder<bool>(
      future: ScanningPreferencesService.isDefaultEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;
        final defaultOption = snapshot.hasData
            ? ScanningPreferencesService.getDefaultScanningOption()
            : null;

        return Card(
          color: Colors.blue[50],
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Scanning',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isEnabled)
                        FutureBuilder<ScanningOption?>(
                          future:
                          ScanningPreferencesService.getDefaultScanningOption(),
                          builder: (context, snapshot) {
                            final option = snapshot.data;
                            if (option != null && snapshot.hasData) {
                              return Text(
                                'Currently: ${option.title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              );
                            }
                            return SizedBox();
                          },
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (value) async {
                    await ScanningPreferencesService.setDefaultEnabled(value);
                    if (context.mounted) {
                      _showDefaultOptionStatus(context, value);
                    }
                  },
                  activeThumbColor: Colors.blue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildRecentBarcodesSection(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: ScanningPreferencesService.getRecentBarcodes(),
      builder: (context, snapshot) {
        final recentBarcodes = snapshot.data ?? [];
        if (recentBarcodes.isEmpty) return SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Barcodes:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: recentBarcodes.map((barcode) {
                return ActionChip(
                  label: Text(barcode),
                  onPressed: () {
                    Navigator.of(context).pop(barcode);
                  },
                  avatar: Icon(Icons.history, size: 16),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  static Widget _buildUniversalBarcodeOption(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Future<String?> Function() onTap,
        required VoidCallback onSetDefault,
      }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue, size: 30),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, size: 20),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'set_default',
              child: Row(
                children: [
                  Icon(Icons.star, size: 20, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Set as Default'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'set_default') {
              onSetDefault();
            }
          },
        ),
        onTap: () async {
          final result = await onTap();
          if (context.mounted) {
            Navigator.of(context).pop(result);
          }
        },
      ),
    );
  }

  static Widget _buildResetDefaultsButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: ScanningPreferencesService.isDefaultEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;

        if (!isEnabled) return SizedBox();

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showResetConfirmationDialog(context),
            icon: Icon(Icons.restore, size: 18),
            label: Text('Reset Default Settings'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orange),
            ),
          ),
        );
      },
    );
  }

  // Dialog and confirmation methods
  static Future<void> _setDefaultScanningOption(
      BuildContext context,
      ScanningOption option,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Default Scanning'),
        content: Text(
          'Set "${option.title}" as your default scanning method? '
              'This will skip the selection menu and go directly to scanning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Set as Default'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ScanningPreferencesService.setDefaultScanningOption(option);
      await ScanningPreferencesService.setDefaultEnabled(true);

      if (context.mounted) {
        _showDefaultSetSuccess(context, option);
      }
    }
  }

  static void _showDefaultSetSuccess(
      BuildContext context,
      ScanningOption option,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Default scanning set to ${option.title}')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  static void _showDefaultOptionStatus(BuildContext context, bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'Default scanning enabled' : 'Default scanning disabled',
        ),
        backgroundColor: enabled ? Colors.green : Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  static void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Default Settings'),
        content: Text(
          'Are you sure you want to reset all default scanning settings? '
              'This will clear your preferred scanning method.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ScanningPreferencesService.resetDefaults();
              if (context.mounted) {
                Navigator.of(context).pop();
                _showResetSuccess(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Reset Defaults'),
          ),
        ],
      ),
    );
  }

  static void _showResetSuccess(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Default settings reset successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Scanning Options Enum
enum ScanningOption {
  camera('Camera Scan', Icons.camera_alt, 'Use device camera'),
  hardware(
    'Hardware Scanner',
    Icons.keyboard_return,
    'Use a connected barcode scanner',
  ),
  manual('Manual Entry', Icons.keyboard, 'Type barcode manually');

  final String title;
  final IconData icon;
  final String subtitle;

  const ScanningOption(this.title, this.icon, this.subtitle);
}

// Global Scanning Settings Screen
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
    final defaultOption =
    await ScanningPreferencesService.getDefaultScanningOption();
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Recent barcodes cleared')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scanning Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Scanning Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDefaultScanningToggle(),
                    SizedBox(height: 16),
                    _buildDefaultOptionSelector(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Barcodes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildRecentBarcodesSection(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildResetButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultScanningToggle() {
    return Row(
      children: [
        Icon(Icons.auto_awesome, color: Colors.blue),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Use Default Scanning', style: TextStyle(fontSize: 16)),
              if (_isDefaultEnabled && _currentDefaultOption != null)
                Text(
                  'Current: ${_currentDefaultOption!.title}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        Switch(value: _isDefaultEnabled, onChanged: _toggleDefaultScanning),
      ],
    );
  }

  Widget _buildDefaultOptionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Scanning Method:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ScanningOption.values.map((option) {
            final isSelected = _currentDefaultOption == option;
            return ChoiceChip(
              label: Text(option.title),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _setDefaultOption(option);
                }
              },
              selectedColor: Colors.blue[100],
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[800] : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        if (!_isDefaultEnabled && _currentDefaultOption != null)
          Text(
            'Note: Turn on "Use Default Scanning" to activate ${_currentDefaultOption!.title}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildRecentBarcodesSection() {
    if (_recentBarcodes.isEmpty) {
      return Column(
        children: [
          Text('No recent barcodes'),
          SizedBox(height: 8),
          Text(
            'Scanned barcodes will appear here for quick access',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recently scanned barcodes:'),
        SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _recentBarcodes.map((barcode) {
                return Chip(
                  label: Text(
                    barcode,
                    style: TextStyle(fontFamily: 'Monospace'),
                  ),
                  backgroundColor: Colors.grey[100],
                  deleteIconColor: Colors.grey[600],
                  onDeleted: () {
                    // For individual deletion, you could implement this:
                    // _removeRecentBarcode(barcode);
                  },
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: 12),
        OutlinedButton(
          onPressed: _clearRecentBarcodes,
          child: Text('Clear All Recent Barcodes'),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _resetAllSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        child: Text('Reset All Scanning Settings'),
      ),
    );
  }
}
class HardwareScannerScreen extends StatefulWidget {
  const HardwareScannerScreen({super.key});

  @override
  _HardwareScannerScreenState createState() => _HardwareScannerScreenState();
}

class _HardwareScannerScreenState extends State<HardwareScannerScreen> {
  final FocusNode _focusNode = FocusNode();
  final StringBuffer _buffer = StringBuffer();
  Timer? _inputTimer;
  static const Duration _inputDelay = Duration(milliseconds: 300);
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _onKey(RawKeyEvent event) {
    if (_scanned || event is! RawKeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _finalizeScan();
    } else {
      final character = event.character;
      if (character != null && character.trim().isNotEmpty) {
        _buffer.write(character);
        _inputTimer?.cancel();
        _inputTimer = Timer(_inputDelay, _finalizeScan);
      }
    }
  }

  void _finalizeScan() {
    if (_scanned) return;
    _scanned = true;
    final scanned = _buffer.toString().trim();
    Navigator.of(context).pop(scanned);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _inputTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan with Hardware Device')),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _onKey,
        child: Center(
          child: Text(
            'Waiting for input from connected scanner...',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

// Enhanced CartScreen with discount support

// Cart Item Card
// Cart Item Card

class OfflineInvoiceBottomSheet extends StatefulWidget {
  final int pendingOrderId;
  final Customer? customer;
  final Map<String, dynamic> businessInfo;
  final Map<String, dynamic> invoiceSettings;
  final double finalTotal;
  final String paymentMethod;
  final Map<String, dynamic>? enhancedData;

  const OfflineInvoiceBottomSheet({
    super.key,
    required this.pendingOrderId,
    this.customer,
    required this.businessInfo,
    required this.invoiceSettings,
    required this.finalTotal,
    required this.paymentMethod,
    this.enhancedData,
  });

  @override
  _OfflineInvoiceBottomSheetState createState() => _OfflineInvoiceBottomSheetState();
}

class _OfflineInvoiceBottomSheetState extends State<OfflineInvoiceBottomSheet> {
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

  // void _generateInvoice() async {
  //   // Create a mock order for offline invoice
  //   final mockOrder = AppOrder(
  //     id: 'offline_${widget.pendingOrderId}',
  //     number: widget.pendingOrderId.toString(),
  //     lineItems: [],
  //     // Add other required fields...
  //   );
  //
  //   // Use enhanced invoice creation if enhanced data is available
  //   final invoice = widget.enhancedData != null
  //       ? Invoice.fromEnhancedOrder(
  //     mockOrder,
  //     widget.customer,
  //     widget.businessInfo,
  //     widget.invoiceSettings,
  //     templateType: _selectedTemplate,
  //     enhancedData: widget.enhancedData,
  //   )
  //       : Invoice.fromOrder(
  //     mockOrder,
  //     widget.customer,
  //     widget.businessInfo,
  //     widget.invoiceSettings,
  //     templateType: _selectedTemplate,
  //   );
  //
  //   // Generate PDF
  //   final pdfFile = await InvoiceService().generatePdfInvoice(invoice);
  //
  //   // Auto print if enabled
  //   if (_autoPrint) {
  //     await InvoiceService().printInvoice(invoice);
  //   }
  //
  //   // Show success dialog
  //   _showSuccessDialog(invoice, pdfFile);
  // }

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
              'Generate Offline Invoice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

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

            // Template Selection and other UI elements...
            // ... (similar to InvoiceOptionsBottomSheetWithOptions)
          ],
        ),
      ),
    );
  }
}
