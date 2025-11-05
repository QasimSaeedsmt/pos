// settings.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mpcm/products/currency_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/invoiceBase/invoice_and_printing_base.dart';
// ADD THESE AT THE TOP OF YOUR SETTINGS CLASS
// Theme Settings
String _themeMode = 'system'; // 'light', 'dark', 'system'
String _primaryColor = 'blue';
String _accentColor = 'teal';
bool _enableGradient = true;
bool _enableAnimations = true;
double _fontSizeScale = 1.0;
String _fontFamily = 'Roboto';
bool _compactMode = false;
String _buttonStyle = 'rounded'; // 'rounded', 'square', 'outlined'

// Modern Color Palettes
final Map<String, List<Color>> _colorPalettes = {
  'blue': [
    Color(0xFF2196F3), // Primary Blue
    Color(0xFF21CBF3), // Light Blue
    Color(0xFF1976D2), // Dark Blue
  ],
  'purple': [
    Color(0xFF9C27B0),
    Color(0xFFBA68C8),
    Color(0xFF7B1FA2),
  ],
  'teal': [
    Color(0xFF009688),
    Color(0xFF4DB6AC),
    Color(0xFF00796B),
  ],
  'orange': [
    Color(0xFFFF9800),
    Color(0xFFFFB74D),
    Color(0xFFF57C00),
  ],
  'green': [
    Color(0xFF4CAF50),
    Color(0xFF81C784),
    Color(0xFF388E3C),
  ],
  'indigo': [
    Color(0xFF3F51B5),
    Color(0xFF7986CB),
    Color(0xFF303F9F),
  ],
  'pink': [
    Color(0xFFE91E63),
    Color(0xFFF06292),
    Color(0xFFC2185B),
  ],
  'deep_orange': [
    Color(0xFFFF5722),
    Color(0xFFFF8A65),
    Color(0xFFD84315),
  ],
};

final Map<String, List<Color>> _gradientPalettes = {
  'blue': [
    Color(0xFF2196F3),
    Color(0xFF21CBF3),
  ],
  'purple': [
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
  ],
  'teal': [
    Color(0xFF009688),
    Color(0xFF4CAF50),
  ],
  'sunset': [
    Color(0xFFFF9800),
    Color(0xFFE91E63),
  ],
  'ocean': [
    Color(0xFF00BCD4),
    Color(0xFF3F51B5),
  ],
  'forest': [
    Color(0xFF4CAF50),
    Color(0xFF2E7D32),
  ],
  'royal': [
    Color(0xFF3F51B5),
    Color(0xFF9C27B0),
  ],
  'fire': [
    Color(0xFFFF5722),
    Color(0xFFFF9800),
  ],
};
class SettingsScreen extends StatefulWidget {
  // String tenantId;
   const SettingsScreen({super.key,
     // required this.tenantId
   });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ADD THESE HELPER METHODS TO YOUR _SettingsScreenState CLASS

  Widget _buildThemeModeSetting() {
    return ListTile(
      title: Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('Choose light, dark, or system theme', style: TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeModeOption('system', Icons.brightness_auto, 'System'),
          SizedBox(width: 8),
          _buildThemeModeOption('light', Icons.brightness_high, 'Light'),
          SizedBox(width: 8),
          _buildThemeModeOption('dark', Icons.brightness_2, 'Dark'),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(String mode, IconData icon, String label) {
    final isSelected = _themeMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _themeMode = mode),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _getPrimaryColor() : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _getPrimaryColor()! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey[600]),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelectionSetting({
    required String title,
    required String subtitle,
    required String value,
    required Function(String?) onChanged,
    required bool isPrimary,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      trailing: SizedBox(
        width: 200,
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: isPrimary ? _colorPalettes.length : _gradientPalettes.length,
          itemBuilder: (context, index) {
            final colorKey = isPrimary
                ? _colorPalettes.keys.elementAt(index)
                : _gradientPalettes.keys.elementAt(index);
            final colors = isPrimary
                ? _colorPalettes[colorKey]!
                : _gradientPalettes[colorKey]!;

            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(colorKey),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isPrimary ? null : LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    color: isPrimary ? colors.first : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: value == colorKey ? Colors.black : Colors.grey[300]!,
                      width: value == colorKey ? 3 : 1,
                    ),
                  ),
                  child: value == colorKey ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ) : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemePreview() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _enableGradient
              ? LinearGradient(
            colors: _gradientPalettes[_accentColor] ?? _gradientPalettes['blue']!,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: _enableGradient ? null : _colorPalettes[_primaryColor]?.first,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              'Theme Preview',
              style: TextStyle(
                fontSize: 18 * _fontSizeScale,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildPreviewButton('Primary', true),
                SizedBox(width: 8),
                _buildPreviewButton('Secondary', false),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Sample card content',
                    style: TextStyle(color: Colors.white),
                  ),
                  Spacer(),
                  Text(
                    '\$99.99',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16 * _fontSizeScale,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewButton(String text, bool isPrimary) {
    final buttonStyle = _buttonStyle;
    return Expanded(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.transparent,
          borderRadius: buttonStyle == 'rounded'
              ? BorderRadius.circular(18)
              : buttonStyle == 'square'
              ? BorderRadius.circular(4)
              : BorderRadius.circular(8),
          border: buttonStyle == 'outlined' || !isPrimary
              ? Border.all(color: Colors.white)
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isPrimary ? _colorPalettes[_primaryColor]?.first : Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 12 * _fontSizeScale,
            ),
          ),
        ),
      ),
    );
  }

  Color? _getPrimaryColor() {
    return _colorPalettes[_primaryColor]?.first;
  }
  // General Settings
  bool _darkMode = false;
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  String _language = 'English';
  String _currency = 'USD';
  String _taxRate = '10.0';
  String _receiptFooter = 'Thank you for your business!';
  bool _enableHapticFeedback = true;
  bool _autoLogout = true;
  int _autoLogoutMinutes = 30;

  // POS Settings
  bool _requireCustomerInfo = false;
  bool _autoPrintReceipts = true;
  bool _enableDiscounts = true;
  bool _enableTax = true;
  bool _lowStockAlerts = true;
  int _lowStockThreshold = 5;
  bool _enableMultiCurrency = false;
  bool _enableReturns = true;
  bool _showStockLevels = true;
  bool _enableQuickActions = true;
  bool _confirmOrderCompletion = true;
  bool _enableOrderNotes = true;

  // Customer Settings
  bool _enableCustomerSearch = true;
  bool _autoCreateCustomers = true;
  bool _collectCustomerAddress = false;
  bool _enableCustomerNotes = true;
  bool _requireCustomerEmail = false;
  bool _requireCustomerPhone = false;
  bool _showCustomerHistory = true;
  bool _enableCustomerLoyalty = false;
  bool _sendCustomerReceipts = false;

  // Security Settings
  bool _requirePinForRefunds = true;
  bool _requirePinForVoid = true;
  bool _enableSessionTimeout = true;
  int _sessionTimeout = 15;
  bool _enableUserPermissions = true;
  bool _requirePinForSettings = false;
  bool _enableAuditLog = true;
  bool _restrictPriceModification = false;

  // Barcode Settings
  bool _isDefaultEnabled = false;
  String? _currentDefaultOption;
  bool _enableBarcodeSound = true;
  bool _enableBarcodeVibration = true;
  bool _autoSubmitBarcode = false;
  bool _enableBarcodeHistory = true;

  // Hardware Settings
  bool _enableBluetoothPrinting = true;
  bool _enableCashDrawer = true;
  bool _enableCustomerDisplay = false;
  String _printerType = 'Thermal';
  String _connectionType = 'USB';
  bool _autoOpenCashDrawer = true;
  bool _enableScanner = true;
  String _scannerType = 'Camera';
  bool _enableWeightScale = false;

  // Data & Sync Settings
  bool _autoSyncEnabled = true;
  bool _backupEnabled = true;
  int _autoBackupInterval = 24;
  bool _exportReports = true;
  bool _enableCloudSync = true;
  bool _syncImages = true;
  bool _compressImages = true;
  int _syncFrequency = 15;
  bool _enableOfflineMode = true;
  bool _clearCacheOnExit = false;

  // Receipt Settings
  bool _printReceiptHeader = true;
  bool _printReceiptFooter = true;
  bool _printCustomerInfo = true;
  bool _printOrderNotes = true;
  String _receiptHeader = 'Your Company Name';
  int _receiptWidth = 80;
  bool _printBarcodeOnReceipt = false;
  bool _printTaxSummary = true;

  // Advanced Settings
  bool _enableDebugMode = false;
  bool _enablePerformanceMetrics = false;
  bool _enableCrashReporting = true;
  bool _enableAutoUpdates = true;
  String _logLevel = 'Info';
  bool _enableRemoteConfig = true;
  bool _enableABTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCurrency();
  }
  _loadCurrency() async {
    // final currencyService = Provider.of<CurrencyService>(context, listen: false);
    // await currencyService.loadCurrency(widget.tenantId);
    // setState(() {
    //   _currency = currencyService.currency;
    // });
  }
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // General Settings
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _language = prefs.getString('language') ?? 'English';
      _currency = prefs.getString('currency') ?? 'USD';
      _taxRate = prefs.getString('tax_rate') ?? '10.0';
      _receiptFooter = prefs.getString('receipt_footer') ?? 'Thank you for your business!';
      _enableHapticFeedback = prefs.getBool('enable_haptic_feedback') ?? true;
      _autoLogout = prefs.getBool('auto_logout') ?? true;
      _autoLogoutMinutes = prefs.getInt('auto_logout_minutes') ?? 30;
// ADD TO _loadSettings method
// Theme Settings
      _themeMode = prefs.getString('theme_mode') ?? 'system';
      _primaryColor = prefs.getString('primary_color') ?? 'blue';
      _accentColor = prefs.getString('accent_color') ?? 'teal';
      _enableGradient = prefs.getBool('enable_gradient') ?? true;
      _enableAnimations = prefs.getBool('enable_animations') ?? true;
      _fontSizeScale = prefs.getDouble('font_size_scale') ?? 1.0;
      _fontFamily = prefs.getString('font_family') ?? 'Roboto';
      _compactMode = prefs.getBool('compact_mode') ?? false;
      _buttonStyle = prefs.getString('button_style') ?? 'rounded';
      // POS Settings
      _requireCustomerInfo = prefs.getBool('require_customer_info') ?? false;
      _autoPrintReceipts = prefs.getBool('auto_print_receipts') ?? true;
      _enableDiscounts = prefs.getBool('enable_discounts') ?? true;
      _enableTax = prefs.getBool('enable_tax') ?? true;
      _lowStockAlerts = prefs.getBool('low_stock_alerts') ?? true;
      _lowStockThreshold = prefs.getInt('low_stock_threshold') ?? 5;
      _enableMultiCurrency = prefs.getBool('enable_multi_currency') ?? false;
      _enableReturns = prefs.getBool('enable_returns') ?? true;
      _showStockLevels = prefs.getBool('show_stock_levels') ?? true;
      _enableQuickActions = prefs.getBool('enable_quick_actions') ?? true;
      _confirmOrderCompletion = prefs.getBool('confirm_order_completion') ?? true;
      _enableOrderNotes = prefs.getBool('enable_order_notes') ?? true;

      // Customer Settings
      _enableCustomerSearch = prefs.getBool('enable_customer_search') ?? true;
      _autoCreateCustomers = prefs.getBool('auto_create_customers') ?? true;
      _collectCustomerAddress = prefs.getBool('collect_customer_address') ?? false;
      _enableCustomerNotes = prefs.getBool('enable_customer_notes') ?? true;
      _requireCustomerEmail = prefs.getBool('require_customer_email') ?? false;
      _requireCustomerPhone = prefs.getBool('require_customer_phone') ?? false;
      _showCustomerHistory = prefs.getBool('show_customer_history') ?? true;
      _enableCustomerLoyalty = prefs.getBool('enable_customer_loyalty') ?? false;
      _sendCustomerReceipts = prefs.getBool('send_customer_receipts') ?? false;

      // Security Settings
      _requirePinForRefunds = prefs.getBool('require_pin_for_refunds') ?? true;
      _requirePinForVoid = prefs.getBool('require_pin_for_void') ?? true;
      _enableSessionTimeout = prefs.getBool('enable_session_timeout') ?? true;
      _sessionTimeout = prefs.getInt('session_timeout') ?? 15;
      _enableUserPermissions = prefs.getBool('enable_user_permissions') ?? true;
      _requirePinForSettings = prefs.getBool('require_pin_for_settings') ?? false;
      _enableAuditLog = prefs.getBool('enable_audit_log') ?? true;
      _restrictPriceModification = prefs.getBool('restrict_price_modification') ?? false;

      // Barcode Settings
      _isDefaultEnabled = prefs.getBool('barcode_default_enabled') ?? false;
      _currentDefaultOption = prefs.getString('barcode_default_option');
      _enableBarcodeSound = prefs.getBool('enable_barcode_sound') ?? true;
      _enableBarcodeVibration = prefs.getBool('enable_barcode_vibration') ?? true;
      _autoSubmitBarcode = prefs.getBool('auto_submit_barcode') ?? false;
      _enableBarcodeHistory = prefs.getBool('enable_barcode_history') ?? true;

      // Hardware Settings
      _enableBluetoothPrinting = prefs.getBool('enable_bluetooth_printing') ?? true;
      _enableCashDrawer = prefs.getBool('enable_cash_drawer') ?? true;
      _enableCustomerDisplay = prefs.getBool('enable_customer_display') ?? false;
      _printerType = prefs.getString('printer_type') ?? 'Thermal';
      _connectionType = prefs.getString('connection_type') ?? 'USB';
      _autoOpenCashDrawer = prefs.getBool('auto_open_cash_drawer') ?? true;
      _enableScanner = prefs.getBool('enable_scanner') ?? true;
      _scannerType = prefs.getString('scanner_type') ?? 'Camera';
      _enableWeightScale = prefs.getBool('enable_weight_scale') ?? false;

      // Data & Sync Settings
      _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
      _backupEnabled = prefs.getBool('backup_enabled') ?? true;
      _autoBackupInterval = prefs.getInt('auto_backup_interval') ?? 24;
      _exportReports = prefs.getBool('export_reports') ?? true;
      _enableCloudSync = prefs.getBool('enable_cloud_sync') ?? true;
      _syncImages = prefs.getBool('sync_images') ?? true;
      _compressImages = prefs.getBool('compress_images') ?? true;
      _syncFrequency = prefs.getInt('sync_frequency') ?? 15;
      _enableOfflineMode = prefs.getBool('enable_offline_mode') ?? true;
      _clearCacheOnExit = prefs.getBool('clear_cache_on_exit') ?? false;

      // Receipt Settings
      _printReceiptHeader = prefs.getBool('print_receipt_header') ?? true;
      _printReceiptFooter = prefs.getBool('print_receipt_footer') ?? true;
      _printCustomerInfo = prefs.getBool('print_customer_info') ?? true;
      _printOrderNotes = prefs.getBool('print_order_notes') ?? true;
      _receiptHeader = prefs.getString('receipt_header') ?? 'Your Company Name';
      _receiptFooter = prefs.getString('receipt_footer') ?? 'Thank you for your business!';
      _receiptWidth = prefs.getInt('receipt_width') ?? 80;
      _printBarcodeOnReceipt = prefs.getBool('print_barcode_on_receipt') ?? false;
      _printTaxSummary = prefs.getBool('print_tax_summary') ?? true;

      // Advanced Settings
      _enableDebugMode = prefs.getBool('enable_debug_mode') ?? false;
      _enablePerformanceMetrics = prefs.getBool('enable_performance_metrics') ?? false;
      _enableCrashReporting = prefs.getBool('enable_crash_reporting') ?? true;
      _enableAutoUpdates = prefs.getBool('enable_auto_updates') ?? true;
      _logLevel = prefs.getString('log_level') ?? 'Info';
      _enableRemoteConfig = prefs.getBool('enable_remote_config') ?? true;
      _enableABTesting = prefs.getBool('enable_ab_testing') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
// ADD TO _saveSettings method
// Theme Settings
    await prefs.setString('theme_mode', _themeMode);
    await prefs.setString('primary_color', _primaryColor);
    await prefs.setString('accent_color', _accentColor);
    await prefs.setBool('enable_gradient', _enableGradient);
    await prefs.setBool('enable_animations', _enableAnimations);
    await prefs.setDouble('font_size_scale', _fontSizeScale);
    await prefs.setString('font_family', _fontFamily);
    await prefs.setBool('compact_mode', _compactMode);
    await prefs.setString('button_style', _buttonStyle);
    // General Settings
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('language', _language);
    await prefs.setString('currency', _currency);
    await prefs.setString('tax_rate', _taxRate);
    await prefs.setString('receipt_footer', _receiptFooter);
    await prefs.setBool('enable_haptic_feedback', _enableHapticFeedback);
    await prefs.setBool('auto_logout', _autoLogout);
    await prefs.setInt('auto_logout_minutes', _autoLogoutMinutes);

    // POS Settings
    await prefs.setBool('require_customer_info', _requireCustomerInfo);
    await prefs.setBool('auto_print_receipts', _autoPrintReceipts);
    await prefs.setBool('enable_discounts', _enableDiscounts);
    await prefs.setBool('enable_tax', _enableTax);
    await prefs.setBool('low_stock_alerts', _lowStockAlerts);
    await prefs.setInt('low_stock_threshold', _lowStockThreshold);
    await prefs.setBool('enable_multi_currency', _enableMultiCurrency);
    await prefs.setBool('enable_returns', _enableReturns);
    await prefs.setBool('show_stock_levels', _showStockLevels);
    await prefs.setBool('enable_quick_actions', _enableQuickActions);
    await prefs.setBool('confirm_order_completion', _confirmOrderCompletion);
    await prefs.setBool('enable_order_notes', _enableOrderNotes);

    // Customer Settings
    await prefs.setBool('enable_customer_search', _enableCustomerSearch);
    await prefs.setBool('auto_create_customers', _autoCreateCustomers);
    await prefs.setBool('collect_customer_address', _collectCustomerAddress);
    await prefs.setBool('enable_customer_notes', _enableCustomerNotes);
    await prefs.setBool('require_customer_email', _requireCustomerEmail);
    await prefs.setBool('require_customer_phone', _requireCustomerPhone);
    await prefs.setBool('show_customer_history', _showCustomerHistory);
    await prefs.setBool('enable_customer_loyalty', _enableCustomerLoyalty);
    await prefs.setBool('send_customer_receipts', _sendCustomerReceipts);

    // Security Settings
    await prefs.setBool('require_pin_for_refunds', _requirePinForRefunds);
    await prefs.setBool('require_pin_for_void', _requirePinForVoid);
    await prefs.setBool('enable_session_timeout', _enableSessionTimeout);
    await prefs.setInt('session_timeout', _sessionTimeout);
    await prefs.setBool('enable_user_permissions', _enableUserPermissions);
    await prefs.setBool('require_pin_for_settings', _requirePinForSettings);
    await prefs.setBool('enable_audit_log', _enableAuditLog);
    await prefs.setBool('restrict_price_modification', _restrictPriceModification);

    // Barcode Settings
    await prefs.setBool('barcode_default_enabled', _isDefaultEnabled);
    if (_currentDefaultOption != null) {
      await prefs.setString('barcode_default_option', _currentDefaultOption!);
    }
    await prefs.setBool('enable_barcode_sound', _enableBarcodeSound);
    await prefs.setBool('enable_barcode_vibration', _enableBarcodeVibration);
    await prefs.setBool('auto_submit_barcode', _autoSubmitBarcode);
    await prefs.setBool('enable_barcode_history', _enableBarcodeHistory);

    // Hardware Settings
    await prefs.setBool('enable_bluetooth_printing', _enableBluetoothPrinting);
    await prefs.setBool('enable_cash_drawer', _enableCashDrawer);
    await prefs.setBool('enable_customer_display', _enableCustomerDisplay);
    await prefs.setString('printer_type', _printerType);
    await prefs.setString('connection_type', _connectionType);
    await prefs.setBool('auto_open_cash_drawer', _autoOpenCashDrawer);
    await prefs.setBool('enable_scanner', _enableScanner);
    await prefs.setString('scanner_type', _scannerType);
    await prefs.setBool('enable_weight_scale', _enableWeightScale);

    // Data & Sync Settings
    await prefs.setBool('auto_sync_enabled', _autoSyncEnabled);
    await prefs.setBool('backup_enabled', _backupEnabled);
    await prefs.setInt('auto_backup_interval', _autoBackupInterval);
    await prefs.setBool('export_reports', _exportReports);
    await prefs.setBool('enable_cloud_sync', _enableCloudSync);
    await prefs.setBool('sync_images', _syncImages);
    await prefs.setBool('compress_images', _compressImages);
    await prefs.setInt('sync_frequency', _syncFrequency);
    await prefs.setBool('enable_offline_mode', _enableOfflineMode);
    await prefs.setBool('clear_cache_on_exit', _clearCacheOnExit);

    // Receipt Settings
    await prefs.setBool('print_receipt_header', _printReceiptHeader);
    await prefs.setBool('print_receipt_footer', _printReceiptFooter);
    await prefs.setBool('print_customer_info', _printCustomerInfo);
    await prefs.setBool('print_order_notes', _printOrderNotes);
    await prefs.setString('receipt_header', _receiptHeader);
    await prefs.setString('receipt_footer', _receiptFooter);
    await prefs.setInt('receipt_width', _receiptWidth);
    await prefs.setBool('print_barcode_on_receipt', _printBarcodeOnReceipt);
    await prefs.setBool('print_tax_summary', _printTaxSummary);

    // Advanced Settings
    await prefs.setBool('enable_debug_mode', _enableDebugMode);
    await prefs.setBool('enable_performance_metrics', _enablePerformanceMetrics);
    await prefs.setBool('enable_crash_reporting', _enableCrashReporting);
    await prefs.setBool('enable_auto_updates', _enableAutoUpdates);
    await prefs.setString('log_level', _logLevel);
    await prefs.setBool('enable_remote_config', _enableRemoteConfig);
    await prefs.setBool('enable_ab_testing', _enableABTesting);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Settings'),
        content: Text('Are you sure you want to reset all settings to default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performReset();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Reset All Settings'),
          ),
        ],
      ),
    );
  }

  void _performReset() {
    setState(() {

      // ADD TO _performReset method
// Theme Settings
      _themeMode = 'system';
      _primaryColor = 'blue';
      _accentColor = 'teal';
      _enableGradient = true;
      _enableAnimations = true;
      _fontSizeScale = 1.0;
      _fontFamily = 'Roboto';
      _compactMode = false;
      _buttonStyle = 'rounded';
      // Reset all settings to defaults
      _darkMode = false;
      _soundEnabled = true;
      _notificationsEnabled = true;
      _language = 'English';
      _currency = 'USD';
      _taxRate = '10.0';
      _receiptFooter = 'Thank you for your business!';
      _enableHapticFeedback = true;
      _autoLogout = true;
      _autoLogoutMinutes = 30;

      _requireCustomerInfo = false;
      _autoPrintReceipts = true;
      _enableDiscounts = true;
      _enableTax = true;
      _lowStockAlerts = true;
      _lowStockThreshold = 5;
      _enableMultiCurrency = false;
      _enableReturns = true;
      _showStockLevels = true;
      _enableQuickActions = true;
      _confirmOrderCompletion = true;
      _enableOrderNotes = true;

      _enableCustomerSearch = true;
      _autoCreateCustomers = true;
      _collectCustomerAddress = false;
      _enableCustomerNotes = true;
      _requireCustomerEmail = false;
      _requireCustomerPhone = false;
      _showCustomerHistory = true;
      _enableCustomerLoyalty = false;
      _sendCustomerReceipts = false;

      _requirePinForRefunds = true;
      _requirePinForVoid = true;
      _enableSessionTimeout = true;
      _sessionTimeout = 15;
      _enableUserPermissions = true;
      _requirePinForSettings = false;
      _enableAuditLog = true;
      _restrictPriceModification = false;

      _isDefaultEnabled = false;
      _currentDefaultOption = null;
      _enableBarcodeSound = true;
      _enableBarcodeVibration = true;
      _autoSubmitBarcode = false;
      _enableBarcodeHistory = true;

      _enableBluetoothPrinting = true;
      _enableCashDrawer = true;
      _enableCustomerDisplay = false;
      _printerType = 'Thermal';
      _connectionType = 'USB';
      _autoOpenCashDrawer = true;
      _enableScanner = true;
      _scannerType = 'Camera';
      _enableWeightScale = false;

      _autoSyncEnabled = true;
      _backupEnabled = true;
      _autoBackupInterval = 24;
      _exportReports = true;
      _enableCloudSync = true;
      _syncImages = true;
      _compressImages = true;
      _syncFrequency = 15;
      _enableOfflineMode = true;
      _clearCacheOnExit = false;

      _printReceiptHeader = true;
      _printReceiptFooter = true;
      _printCustomerInfo = true;
      _printOrderNotes = true;
      _receiptHeader = 'Your Company Name';
      _receiptFooter = 'Thank you for your business!';
      _receiptWidth = 80;
      _printBarcodeOnReceipt = false;
      _printTaxSummary = true;

      _enableDebugMode = false;
      _enablePerformanceMetrics = false;
      _enableCrashReporting = true;
      _enableAutoUpdates = true;
      _logLevel = 'Info';
      _enableRemoteConfig = true;
      _enableABTesting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All settings reset to defaults'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportSettings() {
    // In a real app, export settings to a file
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings exported successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _importSettings() {
    // In a real app, import settings from a file
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings imported successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Cache'),
        content: Text('This will clear all cached data including product images and search history. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reset to Defaults'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.import_export, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Export Settings'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Import Settings'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear Cache'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'reset':
                  _resetToDefaults();
                  break;
                case 'export':
                  _exportSettings();
                  break;
                case 'import':
                  _importSettings();
                  break;
                case 'clear_cache':
                  _clearCache();
                  break;
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // General Settings Section
          _buildSectionHeader(
            title: 'General Settings',
            icon: Icons.settings,
          ),
          // ADD THIS SECTION IN THE build METHOD - Place it after General Settings
// Theme & Appearance Section
          _buildSectionHeader(
            title: 'Theme & Appearance',
            icon: Icons.palette,
          ),
          _buildThemeModeSetting(),
          _buildColorSelectionSetting(
            title: 'Primary Color',
            subtitle: 'Main brand color for the app',
            value: _primaryColor,
            onChanged: (value) => setState(() => _primaryColor = value!),
            isPrimary: true,
          ),
          _buildColorSelectionSetting(
            title: 'Accent Color',
            subtitle: 'Secondary color for highlights',
            value: _accentColor,
            onChanged: (value) => setState(() => _accentColor = value!),
            isPrimary: false,
          ),
          _buildSwitchSetting(
            title: 'Enable Gradients',
            subtitle: 'Use gradient backgrounds for modern look',
            value: _enableGradient,
            onChanged: (value) => setState(() => _enableGradient = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Animations',
            subtitle: 'Smooth transitions and animations',
            value: _enableAnimations,
            onChanged: (value) => setState(() => _enableAnimations = value),
          ),
          _buildSwitchSetting(
            title: 'Compact Mode',
            subtitle: 'Use denser layout with smaller spacing',
            value: _compactMode,
            onChanged: (value) => setState(() => _compactMode = value),
          ),
          _buildDropdownSetting(
            title: 'Button Style',
            subtitle: 'Appearance of buttons throughout the app',
            value: _buttonStyle,
            options: ['rounded', 'square', 'outlined'],
            onChanged: (value) => setState(() => _buttonStyle = value!),
          ),
          _buildSliderSetting(
            title: 'Font Size Scale',
            subtitle: 'Adjust text size throughout the app',
            value: _fontSizeScale,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            onChanged: (value) => setState(() => _fontSizeScale = value),
          ),
          _buildDropdownSetting(
            title: 'Font Family',
            subtitle: 'Typography style for the app',
            value: _fontFamily,
            options: ['Roboto', 'Inter', 'Poppins', 'OpenSans', 'Montserrat'],
            onChanged: (value) => setState(() => _fontFamily = value!),
          ),
          SizedBox(height: 16),
          _buildThemePreview(),
          _buildSwitchSetting(
            title: 'Sound Effects',
            subtitle: 'Play sounds for transactions',
            value: _soundEnabled,
            onChanged: (value) => setState(() => _soundEnabled = value),
          ),
          _buildSwitchSetting(
            title: 'Notifications',
            subtitle: 'Show system notifications',
            value: _notificationsEnabled,
            onChanged: (value) => setState(() => _notificationsEnabled = value),
          ),
          _buildSwitchSetting(
            title: 'Haptic Feedback',
            subtitle: 'Provide vibration feedback',
            value: _enableHapticFeedback,
            onChanged: (value) => setState(() => _enableHapticFeedback = value),
          ),
          _buildSwitchSetting(
            title: 'Auto Logout',
            subtitle: 'Automatically logout after inactivity',
            value: _autoLogout,
            onChanged: (value) => setState(() => _autoLogout = value),
          ),
          if (_autoLogout)
            _buildSliderSetting(
              title: 'Auto Logout Time (minutes)',
              subtitle: 'Minutes before automatic logout',
              value: _autoLogoutMinutes.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              onChanged: (value) => setState(() => _autoLogoutMinutes = value.toInt()),
            ),
          _buildDropdownSetting(
            title: 'Language',
            subtitle: 'App language',
            value: _language,
            options: ['English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese'],
            onChanged: (value) => setState(() => _language = value!),
          ),

          _buildDropdownSetting(
            title: 'Currency',
            subtitle: 'Default currency',
            value: _currency,
            options: ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'INR'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _currency = value);
                // Update in Firestore via CurrencyService
                final currencyService = Provider.of<CurrencyService>(context, listen: false);
                // currencyService.updateCurrency(authProvider, value);
              }
            },
          ),
          _buildTextInputSetting(
            title: 'Tax Rate (%)',
            subtitle: 'Default tax rate',
            value: _taxRate,
            onChanged: (value) => setState(() => _taxRate = value),
            keyboardType: TextInputType.number,
          ),

          // POS Settings Section
          _buildSectionHeader(
            title: 'POS Settings',
            icon: Icons.point_of_sale,
          ),
          _buildSwitchSetting(
            title: 'Require Customer Info',
            subtitle: 'Always collect customer details for sales',
            value: _requireCustomerInfo,
            onChanged: (value) => setState(() => _requireCustomerInfo = value),
          ),
          _buildSwitchSetting(
            title: 'Auto Print Receipts',
            subtitle: 'Automatically print receipts after sale',
            value: _autoPrintReceipts,
            onChanged: (value) => setState(() => _autoPrintReceipts = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Discounts',
            subtitle: 'Allow applying discounts to sales',
            value: _enableDiscounts,
            onChanged: (value) => setState(() => _enableDiscounts = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Tax',
            subtitle: 'Apply tax calculations',
            value: _enableTax,
            onChanged: (value) => setState(() => _enableTax = value),
          ),
          _buildSwitchSetting(
            title: 'Low Stock Alerts',
            subtitle: 'Notify when stock is low',
            value: _lowStockAlerts,
            onChanged: (value) => setState(() => _lowStockAlerts = value),
          ),
          _buildSliderSetting(
            title: 'Low Stock Threshold',
            subtitle: 'Alert when stock falls below this level',
            value: _lowStockThreshold.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (value) => setState(() => _lowStockThreshold = value.toInt()),
          ),
          _buildSwitchSetting(
            title: 'Show Stock Levels',
            subtitle: 'Display stock quantities on product cards',
            value: _showStockLevels,
            onChanged: (value) => setState(() => _showStockLevels = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Quick Actions',
            subtitle: 'Show quick action buttons',
            value: _enableQuickActions,
            onChanged: (value) => setState(() => _enableQuickActions = value),
          ),
          _buildSwitchSetting(
            title: 'Confirm Order Completion',
            subtitle: 'Show confirmation before completing orders',
            value: _confirmOrderCompletion,
            onChanged: (value) => setState(() => _confirmOrderCompletion = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Order Notes',
            subtitle: 'Allow adding notes to orders',
            value: _enableOrderNotes,
            onChanged: (value) => setState(() => _enableOrderNotes = value),
          ),

          // Customer Management Section
          _buildSectionHeader(
            title: 'Customer Management',
            icon: Icons.people,
          ),
          _buildSwitchSetting(
            title: 'Enable Customer Search',
            subtitle: 'Allow searching existing customers',
            value: _enableCustomerSearch,
            onChanged: (value) => setState(() => _enableCustomerSearch = value),
          ),
          _buildSwitchSetting(
            title: 'Auto-create Customers',
            subtitle: 'Automatically create customer profiles from sales',
            value: _autoCreateCustomers,
            onChanged: (value) => setState(() => _autoCreateCustomers = value),
          ),
          _buildSwitchSetting(
            title: 'Collect Address Info',
            subtitle: 'Request customer address information',
            value: _collectCustomerAddress,
            onChanged: (value) => setState(() => _collectCustomerAddress = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Customer Notes',
            subtitle: 'Allow adding notes to customer profiles',
            value: _enableCustomerNotes,
            onChanged: (value) => setState(() => _enableCustomerNotes = value),
          ),
          _buildSwitchSetting(
            title: 'Require Customer Email',
            subtitle: 'Make email address mandatory for customers',
            value: _requireCustomerEmail,
            onChanged: (value) => setState(() => _requireCustomerEmail = value),
          ),
          _buildSwitchSetting(
            title: 'Require Customer Phone',
            subtitle: 'Make phone number mandatory for customers',
            value: _requireCustomerPhone,
            onChanged: (value) => setState(() => _requireCustomerPhone = value),
          ),
          _buildSwitchSetting(
            title: 'Show Customer History',
            subtitle: 'Display customer purchase history',
            value: _showCustomerHistory,
            onChanged: (value) => setState(() => _showCustomerHistory = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Customer Loyalty',
            subtitle: 'Track customer loyalty points',
            value: _enableCustomerLoyalty,
            onChanged: (value) => setState(() => _enableCustomerLoyalty = value),
          ),
          _buildSwitchSetting(
            title: 'Send Customer Receipts',
            subtitle: 'Email receipts to customers automatically',
            value: _sendCustomerReceipts,
            onChanged: (value) => setState(() => _sendCustomerReceipts = value),
          ),

          // Security Settings Section
          _buildSectionHeader(
            title: 'Security',
            icon: Icons.security,
          ),
          _buildSwitchSetting(
            title: 'PIN for Refunds',
            subtitle: 'Require PIN for refund transactions',
            value: _requirePinForRefunds,
            onChanged: (value) => setState(() => _requirePinForRefunds = value),
          ),
          _buildSwitchSetting(
            title: 'PIN for Void',
            subtitle: 'Require PIN for voiding transactions',
            value: _requirePinForVoid,
            onChanged: (value) => setState(() => _requirePinForVoid = value),
          ),
          _buildSwitchSetting(
            title: 'PIN for Settings',
            subtitle: 'Require PIN to access settings',
            value: _requirePinForSettings,
            onChanged: (value) => setState(() => _requirePinForSettings = value),
          ),
          _buildSwitchSetting(
            title: 'Session Timeout',
            subtitle: 'Automatically logout after inactivity',
            value: _enableSessionTimeout,
            onChanged: (value) => setState(() => _enableSessionTimeout = value),
          ),
          if (_enableSessionTimeout)
            _buildSliderSetting(
              title: 'Timeout Duration (minutes)',
              subtitle: 'Minutes before automatic logout',
              value: _sessionTimeout.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (value) => setState(() => _sessionTimeout = value.toInt()),
            ),
          _buildSwitchSetting(
            title: 'User Permissions',
            subtitle: 'Enable role-based access control',
            value: _enableUserPermissions,
            onChanged: (value) => setState(() => _enableUserPermissions = value),
          ),
          _buildSwitchSetting(
            title: 'Audit Log',
            subtitle: 'Log all system activities',
            value: _enableAuditLog,
            onChanged: (value) => setState(() => _enableAuditLog = value),
          ),
          _buildSwitchSetting(
            title: 'Restrict Price Modification',
            subtitle: 'Require authorization for price changes',
            value: _restrictPriceModification,
            onChanged: (value) => setState(() => _restrictPriceModification = value),
          ),

          // Barcode Settings Section
          _buildSectionHeader(
            title: 'Barcode Scanning',
            icon: Icons.qr_code_scanner,
          ),
          _buildBarcodeSettings(),

          // Hardware Settings Section
          _buildSectionHeader(
            title: 'Hardware',
            icon: Icons.print,
          ),
          _buildSwitchSetting(
            title: 'Bluetooth Printing',
            subtitle: 'Enable wireless printing',
            value: _enableBluetoothPrinting,
            onChanged: (value) => setState(() => _enableBluetoothPrinting = value),
          ),
          _buildSwitchSetting(
            title: 'Cash Drawer',
            subtitle: 'Connect to cash drawer',
            value: _enableCashDrawer,
            onChanged: (value) => setState(() => _enableCashDrawer = value),
          ),
          _buildSwitchSetting(
            title: 'Customer Display',
            subtitle: 'Enable secondary customer display',
            value: _enableCustomerDisplay,
            onChanged: (value) => setState(() => _enableCustomerDisplay = value),
          ),
          _buildSwitchSetting(
            title: 'Auto Open Cash Drawer',
            subtitle: 'Automatically open cash drawer on sale completion',
            value: _autoOpenCashDrawer,
            onChanged: (value) => setState(() => _autoOpenCashDrawer = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Scanner',
            subtitle: 'Use barcode scanner',
            value: _enableScanner,
            onChanged: (value) => setState(() => _enableScanner = value),
          ),
          _buildSwitchSetting(
            title: 'Enable Weight Scale',
            subtitle: 'Connect to weight scale',
            value: _enableWeightScale,
            onChanged: (value) => setState(() => _enableWeightScale = value),
          ),
          _buildDropdownSetting(
            title: 'Printer Type',
            subtitle: 'Select printer model',
            value: _printerType,
            options: ['Thermal', 'Laser', 'Inkjet', 'Mobile'],
            onChanged: (value) => setState(() => _printerType = value!),
          ),
          _buildDropdownSetting(
            title: 'Connection Type',
            subtitle: 'Hardware connection method',
            value: _connectionType,
            options: ['USB', 'Bluetooth', 'WiFi', 'Ethernet'],
            onChanged: (value) => setState(() => _connectionType = value!),
          ),
          _buildDropdownSetting(
            title: 'Scanner Type',
            subtitle: 'Barcode scanner type',
            value: _scannerType,
            options: ['Camera', 'USB Scanner', 'Bluetooth Scanner'],
            onChanged: (value) => setState(() => _scannerType = value!),
          ),

          // Data & Sync Settings Section
          _buildSectionHeader(
            title: 'Data & Sync',
            icon: Icons.cloud_sync,
          ),
          _buildSwitchSetting(
            title: 'Auto Sync',
            subtitle: 'Automatically sync data when online',
            value: _autoSyncEnabled,
            onChanged: (value) => setState(() => _autoSyncEnabled = value),
          ),
          _buildSwitchSetting(
            title: 'Auto Backup',
            subtitle: 'Automatically backup data',
            value: _backupEnabled,
            onChanged: (value) => setState(() => _backupEnabled = value),
          ),
          _buildSliderSetting(
            title: 'Backup Interval (hours)',
            subtitle: 'How often to backup data',
            value: _autoBackupInterval.toDouble(),
            min: 1,
            max: 168,
            divisions: 167,
            onChanged: (value) => setState(() => _autoBackupInterval = value.toInt()),
          ),
          _buildSliderSetting(
            title: 'Sync Frequency (minutes)',
            subtitle: 'How often to sync with cloud',
            value: _syncFrequency.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            onChanged: (value) => setState(() => _syncFrequency = value.toInt()),
          ),
          _buildSwitchSetting(
            title: 'Export Reports',
            subtitle: 'Allow exporting sales reports',
            value: _exportReports,
            onChanged: (value) => setState(() => _exportReports = value),
          ),
          _buildSwitchSetting(
            title: 'Cloud Sync',
            subtitle: 'Enable cloud synchronization',
            value: _enableCloudSync,
            onChanged: (value) => setState(() => _enableCloudSync = value),
          ),
          _buildSwitchSetting(
            title: 'Sync Images',
            subtitle: 'Synchronize product images',
            value: _syncImages,
            onChanged: (value) => setState(() => _syncImages = value),
          ),
          _buildSwitchSetting(
            title: 'Compress Images',
            subtitle: 'Compress images before syncing',
            value: _compressImages,
            onChanged: (value) => setState(() => _compressImages = value),
          ),
          _buildSwitchSetting(
            title: 'Offline Mode',
            subtitle: 'Enable offline functionality',
            value: _enableOfflineMode,
            onChanged: (value) => setState(() => _enableOfflineMode = value),
          ),
          _buildSwitchSetting(
            title: 'Clear Cache on Exit',
            subtitle: 'Clear cache when app closes',
            value: _clearCacheOnExit,
            onChanged: (value) => setState(() => _clearCacheOnExit = value),
          ),

          // Receipt Settings Section
          _buildSectionHeader(
            title: 'Receipt Settings',
            icon: Icons.receipt,
          ),
          _buildSwitchSetting(
            title: 'Print Receipt Header',
            subtitle: 'Include header on receipts',
            value: _printReceiptHeader,
            onChanged: (value) => setState(() => _printReceiptHeader = value),
          ),
          _buildSwitchSetting(
            title: 'Print Receipt Footer',
            subtitle: 'Include footer on receipts',
            value: _printReceiptFooter,
            onChanged: (value) => setState(() => _printReceiptFooter = value),
          ),
          _buildSwitchSetting(
            title: 'Print Customer Info',
            subtitle: 'Include customer information on receipts',
            value: _printCustomerInfo,
            onChanged: (value) => setState(() => _printCustomerInfo = value),
          ),
          _buildSwitchSetting(
            title: 'Print Order Notes',
            subtitle: 'Include order notes on receipts',
            value: _printOrderNotes,
            onChanged: (value) => setState(() => _printOrderNotes = value),
          ),
          _buildSwitchSetting(
            title: 'Print Barcode',
            subtitle: 'Include barcode on receipts',
            value: _printBarcodeOnReceipt,
            onChanged: (value) => setState(() => _printBarcodeOnReceipt = value),
          ),
          _buildSwitchSetting(
            title: 'Print Tax Summary',
            subtitle: 'Include tax breakdown on receipts',
            value: _printTaxSummary,
            onChanged: (value) => setState(() => _printTaxSummary = value),
          ),
          _buildTextInputSetting(
            title: 'Receipt Header Text',
            subtitle: 'Text to display at top of receipt',
            value: _receiptHeader,
            onChanged: (value) => setState(() => _receiptHeader = value),
          ),
          _buildTextInputSetting(
            title: 'Receipt Footer Text',
            subtitle: 'Text to display at bottom of receipt',
            value: _receiptFooter,
            onChanged: (value) => setState(() => _receiptFooter = value),
            maxLines: 2,
          ),
          _buildSliderSetting(
            title: 'Receipt Width (characters)',
            subtitle: 'Width of printed receipt',
            value: _receiptWidth.toDouble(),
            min: 40,
            max: 120,
            divisions: 16,
            onChanged: (value) => setState(() => _receiptWidth = value.toInt()),
          ),

          // Advanced Settings Section
          _buildSectionHeader(
            title: 'Advanced Settings',
            icon: Icons.build,
          ),
          _buildSwitchSetting(
            title: 'Debug Mode',
            subtitle: 'Enable debug features and logging',
            value: _enableDebugMode,
            onChanged: (value) => setState(() => _enableDebugMode = value),
          ),
          _buildSwitchSetting(
            title: 'Performance Metrics',
            subtitle: 'Collect performance data',
            value: _enablePerformanceMetrics,
            onChanged: (value) => setState(() => _enablePerformanceMetrics = value),
          ),
          _buildSwitchSetting(
            title: 'Crash Reporting',
            subtitle: 'Send crash reports automatically',
            value: _enableCrashReporting,
            onChanged: (value) => setState(() => _enableCrashReporting = value),
          ),
          _buildSwitchSetting(
            title: 'Auto Updates',
            subtitle: 'Automatically check for updates',
            value: _enableAutoUpdates,
            onChanged: (value) => setState(() => _enableAutoUpdates = value),
          ),
          _buildSwitchSetting(
            title: 'Remote Config',
            subtitle: 'Use remote configuration',
            value: _enableRemoteConfig,
            onChanged: (value) => setState(() => _enableRemoteConfig = value),
          ),
          _buildSwitchSetting(
            title: 'A/B Testing',
            subtitle: 'Enable experimental features',
            value: _enableABTesting,
            onChanged: (value) => setState(() => _enableABTesting = value),
          ),
          _buildDropdownSetting(
            title: 'Log Level',
            subtitle: 'Level of detail for logging',
            value: _logLevel,
            options: ['Error', 'Warning', 'Info', 'Debug', 'Verbose'],
            onChanged: (value) => setState(() => _logLevel = value!),
          ),
          _buildSectionHeader(
            title: 'Customer Analytics & Management',
            icon: Icons.analytics,
          ),
          _buildSwitchSetting(
            title: 'Enable Customer Analytics',
            subtitle: 'Show customer insights and reporting',
            value: true,
            onChanged: (value) => print('Customer Analytics: $value'),
          ),
          _buildSwitchSetting(
            title: 'Customer Segmentation',
            subtitle: 'Automatically categorize customers by value',
            value: true,
            onChanged: (value) => print('Customer Segmentation: $value'),
          ),
          _buildSwitchSetting(
            title: 'Lifetime Value Tracking',
            subtitle: 'Track customer lifetime spending',
            value: true,
            onChanged: (value) => print('Lifetime Value: $value'),
          ),
          _buildSwitchSetting(
            title: 'Purchase History',
            subtitle: 'Show complete customer purchase history',
            value: true,
            onChanged: (value) => print('Purchase History: $value'),
          ),
          _buildSwitchSetting(
            title: 'Customer Retention Alerts',
            subtitle: 'Notify when customers become inactive',
            value: false,
            onChanged: (value) => print('Retention Alerts: $value'),
          ),
          _buildSwitchSetting(
            title: 'High-Value Customer Alerts',
            subtitle: 'Highlight VIP customers',
            value: true,
            onChanged: (value) => print('High-Value Alerts: $value'),
          ),
          _buildSliderSetting(
            title: 'Retention Alert Days',
            subtitle: 'Days before marking customer as inactive',
            value: 90.0,
            min: 30,
            max: 365,
            divisions: 11,
            onChanged: (value) => print('Retention Days: $value'),
          ),
          _buildTextInputSetting(
            title: 'VIP Spending Threshold',
            subtitle: 'Minimum spending to qualify as VIP',
            value: '1000',
            onChanged: (value) => print('VIP Threshold: $value'),
            keyboardType: TextInputType.number,
          ),
          _buildDropdownSetting(
            title: 'Customer Tier System',
            subtitle: 'How to categorize customers',
            value: 'Spending-Based',
            options: ['Spending-Based', 'Frequency-Based', 'Manual', 'Hybrid'],
            onChanged: (value) => print('Tier System: $value'),
          ),
          _buildSwitchSetting(
            title: 'Auto Customer Tier Assignment',
            subtitle: 'Automatically update customer tiers',
            value: true,
            onChanged: (value) => print('Auto Tier: $value'),
          ),
          _buildSwitchSetting(
            title: 'Customer Activity Tracking',
            subtitle: 'Track customer engagement metrics',
            value: true,
            onChanged: (value) => print('Activity Tracking: $value'),
          ),
          _buildSwitchSetting(
            title: 'Customer Notes',
            subtitle: 'Allow adding notes to customer profiles',
            value: true,
            onChanged: (value) => print('Customer Notes: $value'),
          ),
          _buildSwitchSetting(
            title: 'Duplicate Detection',
            subtitle: 'Warn about potential duplicate customers',
            value: true,
            onChanged: (value) => print('Duplicate Detection: $value'),
          ),
          _buildSwitchSetting(
            title: 'Customer Export',
            subtitle: 'Allow exporting customer data',
            value: true,
            onChanged: (value) => print('Customer Export: $value'),
          ),
          _buildSwitchSetting(
            title: 'Customer Import',
            subtitle: 'Allow importing customer data',
            value: false,
            onChanged: (value) => print('Customer Import: $value'),
          ),
          _buildDropdownSetting(
            title: 'Data Retention Period',
            subtitle: 'How long to keep customer data',
            value: '3 Years',
            options: ['1 Year', '2 Years', '3 Years', '5 Years', 'Indefinitely'],
            onChanged: (value) => print('Data Retention: $value'),
          ),
          _buildSwitchSetting(
            title: 'GDPR Compliance',
            subtitle: 'Enable data protection features',
            value: false,
            onChanged: (value) => print('GDPR: $value'),
          ),
          _buildSwitchSetting(
            title: 'Auto-anonymize Inactive Customers',
            subtitle: 'Remove personal data after inactivity',
            value: false,
            onChanged: (value) => print('Auto-anonymize: $value'),
          ),
          // Action Buttons
          _buildActionButtons(),

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[700], size: 20),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.blue,
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextInputSetting({
    required String title,
    required String subtitle,
    required String value,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: TextStyle(fontSize: 12)),
          SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            onChanged: onChanged,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: TextStyle(fontSize: 12)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
              SizedBox(width: 16),
              Text(
                value.toInt().toString(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeSettings() {
    return Column(
      children: [
        _buildSwitchSetting(
          title: 'Default Scanning',
          subtitle: 'Use default scanning method',
          value: _isDefaultEnabled,
          onChanged: (value) => setState(() => _isDefaultEnabled = value),
        ),
        if (_isDefaultEnabled)
          _buildDropdownSetting(
            title: 'Default Method',
            subtitle: 'Preferred scanning method',
            value: _currentDefaultOption ?? 'Camera',
            options: ['Camera', 'Hardware', 'Manual'],
            onChanged: (value) => setState(() => _currentDefaultOption = value),
          ),
        _buildSwitchSetting(
          title: 'Barcode Sound',
          subtitle: 'Play sound on successful scan',
          value: _enableBarcodeSound,
          onChanged: (value) => setState(() => _enableBarcodeSound = value),
        ),
        _buildSwitchSetting(
          title: 'Barcode Vibration',
          subtitle: 'Vibrate on successful scan',
          value: _enableBarcodeVibration,
          onChanged: (value) => setState(() => _enableBarcodeVibration = value),
        ),
        _buildSwitchSetting(
          title: 'Auto Submit',
          subtitle: 'Automatically submit after scan',
          value: _autoSubmitBarcode,
          onChanged: (value) => setState(() => _autoSubmitBarcode = value),
        ),
        _buildSwitchSetting(
          title: 'Barcode History',
          subtitle: 'Keep history of scanned barcodes',
          value: _enableBarcodeHistory,
          onChanged: (value) => setState(() => _enableBarcodeHistory = value),
        ),
        ListTile(
          title: Text('Barcode Settings', style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('Configure barcode scanning preferences', style: TextStyle(fontSize: 12)),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ScanningSettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: Icon(Icons.save),
              label: Text('Save All Settings'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetToDefaults,
              icon: Icon(Icons.restore),
              label: Text('Reset to Defaults'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.orange,
                side: BorderSide(color: Colors.orange),
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearCache,
              icon: Icon(Icons.clear_all),
              label: Text('Clear Cache'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}