import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../constants.dart';
import '../connectivityBase/local_db_base.dart';
import '../invoiceBase/invoice_and_printing_base.dart';
import '../main_navigation/main_navigation_base.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../product_selling/product_selling_base.dart';
// bulk_scan_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../connectivityBase/local_db_base.dart';
import '../product_selling/product_selling_base.dart';

// export_screen.dart
import 'package:flutter/material.dart';

import '../connectivityBase/local_db_base.dart';
import '../product_selling/product_selling_base.dart';
// export_screen.dart
import 'package:flutter/material.dart';

import '../connectivityBase/local_db_base.dart';
import '../product_selling/product_selling_base.dart';




class BulkScanResult {
  final String barcode;
  final Product? product;
  final int quantity;
  final bool isNewProduct;

  BulkScanResult({
    required this.barcode,
    this.product,
    this.quantity = 1,
    this.isNewProduct = false,
  });
}

class BulkScanService {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final LocalDatabase _localDb = LocalDatabase();

  // Track scanned items
  final Map<String, BulkScanResult> _scannedItems = {};
  final StreamController<List<BulkScanResult>> _scanController =
  StreamController<List<BulkScanResult>>.broadcast();

  Stream<List<BulkScanResult>> get scanStream => _scanController.stream;

  // Process a scanned barcode
  Future<BulkScanResult> processBarcode(String barcode) async {
    try {
      // Check if barcode already exists
      if (_scannedItems.containsKey(barcode)) {
        final existing = _scannedItems[barcode]!;
        final updatedResult = BulkScanResult(
          barcode: barcode,
          product: existing.product,
          quantity: existing.quantity + 1,
          isNewProduct: existing.isNewProduct,
        );
        _scannedItems[barcode] = updatedResult;
        _scanController.add(_scannedItems.values.toList());
        return updatedResult;
      }

      // Search for product
      Product? product;
      if (_posService.isOnline) {
        final products = await _posService.searchProductsBySKU(barcode);
        if (products.isNotEmpty) {
          product = products.first;
        }
      } else {
        product = await _localDb.getProductBySku(barcode);
      }

      final result = BulkScanResult(
        barcode: barcode,
        product: product,
        quantity: 1,
        isNewProduct: product == null,
      );

      _scannedItems[barcode] = result;
      _scanController.add(_scannedItems.values.toList());
      return result;
    } catch (e) {
      throw Exception('Failed to process barcode: $e');
    }
  }

  // Update quantity for a specific barcode
  void updateQuantity(String barcode, int quantity) {
    if (_scannedItems.containsKey(barcode)) {
      final existing = _scannedItems[barcode]!;
      _scannedItems[barcode] = BulkScanResult(
        barcode: barcode,
        product: existing.product,
        quantity: quantity,
        isNewProduct: existing.isNewProduct,
      );
      _scanController.add(_scannedItems.values.toList());
    }
  }

  // Remove a scanned item
  void removeItem(String barcode) {
    _scannedItems.remove(barcode);
    _scanController.add(_scannedItems.values.toList());
  }

  // Clear all scanned items
  void clearAll() {
    _scannedItems.clear();
    _scanController.add(_scannedItems.values.toList());
  }

  // Get current scanned items
  List<BulkScanResult> getScannedItems() {
    return _scannedItems.values.toList();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    final items = _scannedItems.values.toList();
    final totalItems = items.fold(0, (sum, item) => sum + item.quantity);
    final knownProducts = items.where((item) => item.product != null).length;
    final newProducts = items.where((item) => item.isNewProduct).length;

    return {
      'totalScans': items.length,
      'totalItems': totalItems,
      'knownProducts': knownProducts,
      'newProducts': newProducts,
    };
  }

  // Import scanned items to inventory
  Future<Map<String, dynamic>> importToInventory() async {
    try {
      int successfulImports = 0;
      int failedImports = 0;
      List<String> errors = [];

      for (final result in _scannedItems.values) {
        if (result.product != null) {
          try {
            await _posService.restockProduct(result.product!.id, result.quantity);
            successfulImports++;
          } catch (e) {
            failedImports++;
            errors.add('${result.barcode}: $e');
          }
        }
      }

      return {
        'successful': successfulImports,
        'failed': failedImports,
        'errors': errors,
        'total': _scannedItems.length,
      };
    } catch (e) {
      throw Exception('Failed to import to inventory: $e');
    }
  }

  void dispose() {
    _scanController.close();
  }
}


class ExportService {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final LocalDatabase _localDb = LocalDatabase();

  // Export products to CSV
  Future<String> exportToCSV(List<Product> products) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }

      // Create CSV data
      final List<List<dynamic>> csvData = [];

      // Add header row
      csvData.add([
        'ID',
        'Name',
        'SKU',
        'Price',
        'Purchase Price',
        'Stock Quantity',
        'Description',
        'Categories',
        'Image URL',
        'Status',
        'In Stock',
        'Created Date'
      ]);

      // Add product rows
      for (final product in products) {
        final categories = product.categories?.map((c) => c.name).join('; ') ?? '';

        csvData.add([
          product.id,
          product.name,
          product.sku,
          product.price,
          product.purchasePrice ?? '',
          product.stockQuantity,
          product.description ?? '',
          categories,
          product.imageUrl ?? '',
          product.status,
          product.inStock,
          _formatDate(DateTime.now()),
        ]);
      }

      // Convert to CSV
      final csvString = const ListToCsvConverter().convert(csvData);

      // Save to file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/products_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  // Export products to JSON
  Future<String> exportToJSON(List<Product> products) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }

      final List<Map<String, dynamic>> jsonData = [];

      for (final product in products) {
        jsonData.add({
          'id': product.id,
          'name': product.name,
          'sku': product.sku,
          'price': product.price,
          'purchasePrice': product.purchasePrice,
          'stockQuantity': product.stockQuantity,
          'description': product.description,
          'categories': product.categories?.map((c) => c.toFirestore()).toList(),
          'imageUrl': product.imageUrl,
          'status': product.status,
          'inStock': product.inStock,
          'exportedAt': DateTime.now().toIso8601String(),
        });
      }

      final jsonString = jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'totalProducts': products.length,
        'products': jsonData,
      });

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/products_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export JSON: $e');
    }
  }

  // Export inventory summary
  Future<String> exportInventorySummary(List<Product> products) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }

      final totalValue = products.fold(0.0, (sum, p) => sum + (p.price * p.stockQuantity));
      final totalCost = products.fold(0.0, (sum, p) => sum + ((p.purchasePrice ?? p.price * 0.7) * p.stockQuantity));
      final outOfStock = products.where((p) => p.stockQuantity == 0).length;
      final lowStock = products.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 10).length;

      final summaryData = {
        'reportGenerated': DateTime.now().toIso8601String(),
        'totalProducts': products.length,
        'totalStockValue': totalValue,
        'totalCostValue': totalCost,
        'potentialProfit': totalValue - totalCost,
        'outOfStockItems': outOfStock,
        'lowStockItems': lowStock,
        'products': products.map((p) => {
          'name': p.name,
          'sku': p.sku,
          'price': p.price,
          'stock': p.stockQuantity,
          'value': p.price * p.stockQuantity,
          'status': p.stockQuantity == 0 ? 'Out of Stock' : p.stockQuantity <= 10 ? 'Low Stock' : 'In Stock',
        }).toList(),
      };

      final jsonString = jsonEncode(summaryData);
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/inventory_summary_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export summary: $e');
    }
  }

  // Share file
  Future<void> shareFile(String filePath, String subject) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: subject,
        );
      }
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}


class BulkScanScreen extends StatefulWidget {
  const BulkScanScreen({super.key});

  @override
  _BulkScanScreenState createState() => _BulkScanScreenState();
}

class _BulkScanScreenState extends State<BulkScanScreen> {
  final BulkScanService _scanService = BulkScanService();
  final ExportService _exportService = ExportService();
  final TextEditingController _manualBarcodeController = TextEditingController();
  bool _isScanning = false;
  bool _isImporting = false;
  String _scanStatus = 'Ready to scan';

  @override
  void initState() {
    super.initState();
    _manualBarcodeController.addListener(_onManualBarcodeChanged);
  }

  @override
  void dispose() {
    _scanService.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  void _onManualBarcodeChanged() {
    final barcode = _manualBarcodeController.text.trim();
    if (barcode.length >= 3) {
      _processBarcode(barcode);
    }
  }

  Future<void> _processBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() {
      _isScanning = true;
      _scanStatus = 'Processing barcode...';
    });

    try {
      final result = await _scanService.processBarcode(barcode);

      setState(() {
        _scanStatus = result.product != null
            ? '✓ Product found: ${result.product!.name}'
            : '⚠ New product: $barcode';
      });

      // Clear manual input after processing
      if (_manualBarcodeController.text == barcode) {
        _manualBarcodeController.clear();
      }

      // Haptic feedback or sound could be added here
    } catch (e) {
      setState(() {
        _scanStatus = '✗ Error: $e';
      });
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _startCameraScan() async {
    try {
      final barcode = await UniversalScanningService.scanBarcode(
        context,
        purpose: 'bulk_scan',
      );

      if (barcode != null && barcode.isNotEmpty) {
        await _processBarcode(barcode);
      }
    } catch (e) {
      setState(() {
        _scanStatus = '✗ Scan failed: $e';
      });
    }
  }

  Future<void> _importToInventory() async {
    setState(() => _isImporting = true);

    try {
      final result = await _scanService.importToInventory();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Successful: ${result['successful']}'),
              Text('❌ Failed: ${result['failed']}'),
              Text('📊 Total: ${result['total']}'),
              if (result['errors'].isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(result['errors'] as List<String>).take(3).map((error) =>
                    Text('• $error', style: const TextStyle(fontSize: 12))
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Clear after successful import
      if (result['successful'] > 0) {
        _scanService.clearAll();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _exportScannedItems() async {
    try {
      final items = _scanService.getScannedItems();
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items to export')),
        );
        return;
      }

      // Create export data
      final exportData = items.map((item) => {
        'Barcode': item.barcode,
        'Product Name': item.product?.name ?? 'Unknown',
        'Quantity': item.quantity,
        'Status': item.isNewProduct ? 'New Product' : 'Existing Product',
      }).toList();

      final csvData = [['Barcode', 'Product Name', 'Quantity', 'Status']];
      for (final item in exportData) {
        csvData.add([
          item['Barcode']?.toString() ?? '',
          item['Product Name']?.toString() ?? '',
          item['Quantity']?.toString() ?? '',
          item['Status']?.toString() ?? '',
        ]);
      }


      final csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/bulk_scan_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      await _exportService.shareFile(filePath, 'Bulk Scan Export');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan results exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildScanStats() {
    final stats = _scanService.getStatistics();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total Scans', stats['totalScans'].toString(), Icons.qr_code_scanner),
            _buildStatItem('Total Items', stats['totalItems'].toString(), Icons.inventory_2),
            _buildStatItem('Products', stats['knownProducts'].toString(), Icons.check_circle),
            _buildStatItem('New', stats['newProducts'].toString(), Icons.new_releases),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildScanControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _scanStatus,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _scanStatus.startsWith('✓') ? Colors.green :
                _scanStatus.startsWith('⚠') ? Colors.orange :
                _scanStatus.startsWith('✗') ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualBarcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Barcode',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.keyboard),
                    ),
                    enabled: !_isScanning,
                  ),
                ),
                const SizedBox(width: 12),
                _isScanning
                    ? const CircularProgressIndicator()
                    : IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 32),
                  onPressed: _startCameraScan,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannedItemsList() {
    return StreamBuilder<List<BulkScanResult>>(
      stream: _scanService.scanStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No items scanned yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    'Start scanning barcodes to see them here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scanned Items',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.file_download),
                          onPressed: _exportScannedItems,
                          tooltip: 'Export Scan Results',
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all),
                          onPressed: _scanService.clearAll,
                          tooltip: 'Clear All',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildScannedItem(item);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScannedItem(BulkScanResult item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: item.product != null ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            item.product != null ? Icons.check_circle : Icons.new_releases,
            color: item.product != null ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          item.product?.name ?? 'Unknown Product',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: item.product != null ? Colors.black : Colors.orange.shade700,
          ),
        ),
        subtitle: Text('Barcode: ${item.barcode}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                final newQuantity = item.quantity - 1;
                if (newQuantity > 0) {
                  _scanService.updateQuantity(item.barcode, newQuantity);
                } else {
                  _scanService.removeItem(item.barcode);
                }
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${item.quantity}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _scanService.updateQuantity(item.barcode, item.quantity + 1);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _scanService.removeItem(item.barcode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final stats = _scanService.getStatistics();
    final hasItems = stats['totalScans'] > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasItems ? _exportScannedItems : null,
              icon: const Icon(Icons.file_download),
              label: const Text('Export Scan'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: hasItems && !_isImporting ? _importToInventory : null,
              icon: _isImporting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: Text(_isImporting ? 'Importing...' : 'Import to Inventory'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Barcode Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildScanStats(),
            _buildScanControls(),
            _buildScannedItemsList(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Scan Help'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Use camera or manual entry to scan barcodes'),
            Text('• Existing products will be identified automatically'),
            Text('• New products will be marked for review'),
            Text('• Adjust quantities using +/- buttons'),
            Text('• Export scan results or import to inventory'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int count;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.count,
    this.imageUrl,
  });

  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      name: data['name']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      description: data['description']?.toString(),
      count: data['count'] ?? 0,
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'count': count,
      'imageUrl': imageUrl,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    int? count,
    String? imageUrl,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      count: count ?? this.count,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  _CategoryManagementScreenState createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<Category> _categories = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Category> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _categories.where((category) {
        return category.name.toLowerCase().contains(query) ||
            (category.description?.toLowerCase().contains(query) ?? false) ||
            category.slug.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _posService.getCategories();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
        _filteredCategories = List.from(_categories);
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load categories: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => CategoryEditDialog(
        category: null,
        onSave: _addCategory,
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryEditDialog(
        category: category,
        onSave: _updateCategory,
      ),
    );
  }

  Future<void> _addCategory(Category category) async {
    try {
      await _posService.addCategory(category);
      if (!mounted) return;
      Navigator.pop(context);
      _loadCategories();
      _showSuccessSnackBar('Category "${category.name}" added successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to add category: $e');
    }
  }

  Future<void> _updateCategory(Category category) async {
    try {
      await _posService.updateCategory(category);
      if (!mounted) return;
      Navigator.pop(context);
      _loadCategories();
      _showSuccessSnackBar('Category "${category.name}" updated successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to update category: $e');
    }
  }

  void _showDeleteDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        itemName: category.name,
        onConfirm: () => _deleteCategory(category),
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      await _posService.deleteCategory(category.id);
      if (!mounted) return;
      Navigator.pop(context);
      _loadCategories();
      _showSuccessSnackBar('Category "${category.name}" deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to delete category: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 16),
            Text(
              'Loading Categories...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No Categories Yet'
                  : 'No Categories Found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? 'Add categories to organize your products'
                  : 'Try adjusting your search terms',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_searchController.text.isEmpty)
              FilledButton.icon(
                onPressed: _showAddCategoryDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add First Category'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        return CategoryCard(
          category: category,
          onEdit: () => _showEditCategoryDialog(category),
          onDelete: () => _showDeleteDialog(category),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search categories...',
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade500),
            onPressed: () {
              _searchController.clear();
              _filterCategories();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Categories',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCategories,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAddCategoryDialog,
            tooltip: 'Add Category',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(child: _buildCategoryList()),
        ],
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade100,
                    Colors.purple.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.category_rounded,
                color: Colors.blue.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (category.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      category.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category.slug,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontFamily: 'Monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${category.count}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: Colors.grey.shade600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      const Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryEditDialog extends StatefulWidget {
  final Category? category;
  final Function(Category) onSave;

  const CategoryEditDialog({
    super.key,
    this.category,
    required this.onSave,
  });

  @override
  State<CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class CostHistoryScreen extends StatefulWidget {
  final Product product;

  const CostHistoryScreen({super.key, required this.product});

  @override
  _CostHistoryScreenState createState() => _CostHistoryScreenState();
}

class _CostHistoryScreenState extends State<CostHistoryScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  List<PurchaseRecord> _purchaseHistory = [];
  bool _isLoading = true;
  String _errorMessage = '';
  DateTimeRange? _selectedDateRange;
  List<PurchaseRecord> _filteredHistory = [];
  ChartType _selectedChartType = ChartType.timeline;

  @override
  void initState() {
    super.initState();
    _loadPurchaseHistory();
  }

  Future<void> _loadPurchaseHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final history = await _posService.getPurchaseHistory(widget.product.id);
      setState(() {
        _purchaseHistory = history;
        _filteredHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load purchase history: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<PurchaseRecord> filtered = List.from(_purchaseHistory);

    if (_selectedDateRange != null) {
      filtered = filtered.where((record) {
        return record.purchaseDate.isAfter(_selectedDateRange!.start) &&
            record.purchaseDate.isBefore(_selectedDateRange!.end);
      }).toList();
    }

    setState(() {
      _filteredHistory = filtered;
    });
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      saveText: 'Apply',
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = null;
      _filteredHistory = _purchaseHistory;
    });
  }

  double get _totalUnitsPurchased {
    return _filteredHistory.fold(0, (sum, record) => sum + record.quantity);
  }

  double get _totalCost {
    return _filteredHistory.fold(0.0, (sum, record) => sum + record.totalCost);
  }

  double get _averageCostPerUnit {
    return _totalUnitsPurchased > 0 ? _totalCost / _totalUnitsPurchased : 0;
  }

  List<CostDataPoint> get _costTrendData {
    final sortedHistory = List<PurchaseRecord>.from(_filteredHistory)
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    final List<CostDataPoint> data = [];
    double cumulativeUnits = 0;
    double cumulativeCost = 0;

    for (final record in sortedHistory) {
      cumulativeUnits += record.quantity;
      cumulativeCost += record.totalCost;
      final weightedAverage = cumulativeUnits > 0 ? cumulativeCost / cumulativeUnits : 0;

      data.add(CostDataPoint(
        date: record.purchaseDate,
        cost: record.purchasePrice,
        weightedAverage: weightedAverage.toDouble(),
        quantity: record.quantity,
        totalCost: record.totalCost,
      ));
    }

    return data;
  }

  Widget _buildHeaderStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Total Purchases',
              _filteredHistory.length.toString(),
              Icons.receipt_long,
              Colors.blue,
            ),
            _buildStatItem(
              'Total Units',
              _totalUnitsPurchased.toStringAsFixed(0),
              Icons.inventory_2,
              Colors.green,
            ),
            _buildStatItem(
              'Total Cost',
              '${Constants.CURRENCY_NAME}${_totalCost.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.orange,
            ),
            _buildStatItem(
              'Avg Cost/Unit',
              '${Constants.CURRENCY_NAME}${_averageCostPerUnit.toStringAsFixed(2)}',
              Icons.trending_up,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _selectedDateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                    ),
                    onPressed: _showDateRangePicker,
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedDateRange != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Chart Type',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ChartType.values.map((type) {
                return FilterChip(
                  label: Text(_getChartTypeLabel(type)),
                  selected: _selectedChartType == type,
                  onSelected: (selected) {
                    setState(() {
                      _selectedChartType = type;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getChartTypeLabel(ChartType type) {
    switch (type) {
      case ChartType.timeline:
        return 'Cost Timeline';
      case ChartType.quantity:
        return 'Purchase Quantity';
      case ChartType.cumulative:
        return 'Cumulative Cost';
    }
  }

  Widget _buildCharts() {
    if (_costTrendData.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    switch (_selectedChartType) {
      case ChartType.timeline:
        return _buildTimelineChart();
      case ChartType.quantity:
        return _buildQuantityChart();
      case ChartType.cumulative:
        return _buildCumulativeChart();
    }
  }

  Widget _buildTimelineChart() {
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        title: AxisTitle(text: 'Date'),
        dateFormat: DateFormat('MMM dd'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Cost per Unit (${Constants.CURRENCY_NAME})'),
        numberFormat: NumberFormat.simpleCurrency(name: Constants.CURRENCY_NAME),
      ),
      series: <CartesianSeries>[
        LineSeries<CostDataPoint, DateTime>(
          dataSource: _costTrendData,
          xValueMapper: (CostDataPoint data, _) => data.date,
          yValueMapper: (CostDataPoint data, _) => data.cost,
          name: 'Purchase Cost',
          markerSettings: const MarkerSettings(isVisible: true),
          color: Colors.blue,
        ),
        LineSeries<CostDataPoint, DateTime>(
          dataSource: _costTrendData,
          xValueMapper: (CostDataPoint data, _) => data.date,
          yValueMapper: (CostDataPoint data, _) => data.weightedAverage,
          name: 'Weighted Average',
          markerSettings: const MarkerSettings(isVisible: true),
          color: Colors.orange,
          dashArray: [5, 5],
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
    );
  }

  Widget _buildQuantityChart() {
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        title: AxisTitle(text: 'Date'),
        dateFormat: DateFormat('MMM dd'),
      ),
      primaryYAxis: NumericAxis(title: AxisTitle(text: 'Quantity')),
      series: <CartesianSeries>[
        ColumnSeries<CostDataPoint, DateTime>(
          dataSource: _costTrendData,
          xValueMapper: (CostDataPoint data, _) => data.date,
          yValueMapper: (CostDataPoint data, _) => data.quantity,
          name: 'Purchase Quantity',
          color: Colors.green,
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }

  Widget _buildCumulativeChart() {
    double cumulativeCost = 0;
    final cumulativeData = _costTrendData.map((point) {
      cumulativeCost += point.totalCost;
      return CumulativeDataPoint(point.date, cumulativeCost);
    }).toList();

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        title: AxisTitle(text: 'Date'),
        dateFormat: DateFormat('MMM dd'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Cumulative Cost (${Constants.CURRENCY_NAME})'),
        numberFormat: NumberFormat.simpleCurrency(name: Constants.CURRENCY_NAME),
      ),
      series: <CartesianSeries>[
        AreaSeries<CumulativeDataPoint, DateTime>(
          dataSource: cumulativeData,
          xValueMapper: (CumulativeDataPoint data, _) => data.date,
          yValueMapper: (CumulativeDataPoint data, _) => data.cumulativeCost,
          name: 'Cumulative Cost',
          color: Colors.purple.withOpacity(0.3),
          borderColor: Colors.purple,
          borderWidth: 2,
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }

  Widget _buildPurchaseList() {
    if (_filteredHistory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Purchase History',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Purchase records will appear here after restocking',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Purchase History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._filteredHistory.map((record) => _buildPurchaseItem(record)),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseItem(PurchaseRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(record.purchaseDate),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${record.quantity} units',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cost per Unit: ${Constants.CURRENCY_NAME}${record.purchasePrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (record.supplier != null && record.supplier!.isNotEmpty)
                    Text(
                      'Supplier: ${record.supplier}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  if (record.batchNumber != null && record.batchNumber!.isNotEmpty)
                    Text(
                      'Batch: ${record.batchNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total: ${Constants.CURRENCY_NAME}${record.totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  if (record.notes != null && record.notes!.isNotEmpty)
                    SizedBox(
                      width: 150,
                      child: Text(
                        'Notes: ${record.notes}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCostSummary() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Cost Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weighted Average Cost:'),
                Text(
                  '${Constants.CURRENCY_NAME}${widget.product.purchasePrice?.toStringAsFixed(2) ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Stock:'),
                Text(
                  '${widget.product.stockQuantity} units',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Inventory Value:'),
                Text(
                  '${Constants.CURRENCY_NAME}${widget.product.inventoryValue.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Units Purchased:'),
                Text(
                  '${widget.product.totalUnitsPurchased}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cost History - ${widget.product.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPurchaseHistory,
            tooltip: 'Refresh',
          ),
          if (_filteredHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.insights),
              onPressed: () {
                // Show detailed analytics
                _showAnalyticsDialog();
              },
              tooltip: 'View Analytics',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Unable to Load History',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: _loadPurchaseHistory,
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderStats(),
            const SizedBox(height: 16),
            _buildCurrentCostSummary(),
            const SizedBox(height: 16),
            _buildFilters(),
            if (_costTrendData.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildCharts(),
            ],
            const SizedBox(height: 16),
            _buildPurchaseList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cost Analytics'),
        content: SizedBox(
          width: double.maxFinite,
          child: _buildAnalyticsContent(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    if (_filteredHistory.isEmpty) return const Text('No data available');

    final sortedByCost = List<PurchaseRecord>.from(_filteredHistory)
      ..sort((a, b) => a.purchasePrice.compareTo(b.purchasePrice));

    final lowestCost = sortedByCost.first.purchasePrice;
    final highestCost = sortedByCost.last.purchasePrice;
    final costRange = highestCost - lowestCost;

    final totalUnits = _totalUnitsPurchased;
    final avgCost = _averageCostPerUnit;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsItem('Lowest Purchase Cost', '${Constants.CURRENCY_NAME}${lowestCost.toStringAsFixed(2)}'),
          _buildAnalyticsItem('Highest Purchase Cost', '${Constants.CURRENCY_NAME}${highestCost.toStringAsFixed(2)}'),
          _buildAnalyticsItem('Cost Range', '${Constants.CURRENCY_NAME}${costRange.toStringAsFixed(2)}'),
          _buildAnalyticsItem('Average Cost per Unit', '${Constants.CURRENCY_NAME}${avgCost.toStringAsFixed(2)}'),
          _buildAnalyticsItem('Total Investment', '${Constants.CURRENCY_NAME}${_totalCost.toStringAsFixed(2)}'),
          _buildAnalyticsItem('Average Purchase Size', '${(totalUnits / _filteredHistory.length).toStringAsFixed(1)} units'),

          const SizedBox(height: 16),
          const Text(
            'Cost Distribution',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._buildCostDistribution(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCostDistribution() {
    final costRanges = {
      'Low (< ${Constants.CURRENCY_NAME}${(_averageCostPerUnit * 0.8).toStringAsFixed(2)})': 0,
      'Average': 0,
      'High (> ${Constants.CURRENCY_NAME}${(_averageCostPerUnit * 1.2).toStringAsFixed(2)})': 0,
    };

    for (final record in _filteredHistory) {
      final lowKey =
          'Low (< ${Constants.CURRENCY_NAME}${(_averageCostPerUnit * 0.8).toStringAsFixed(2)})';
      final highKey =
          'High (> ${Constants.CURRENCY_NAME}${(_averageCostPerUnit * 1.2).toStringAsFixed(2)})';

      if (record.purchasePrice < _averageCostPerUnit * 0.8) {
        costRanges[lowKey] = costRanges[lowKey]! + 1;
      } else if (record.purchasePrice > _averageCostPerUnit * 1.2) {
        costRanges[highKey] = costRanges[highKey]! + 1;
      } else {
        costRanges['Average'] = costRanges['Average']! + 1;
      }
    }


    return costRanges.entries.map((entry) {
      final percentage = (entry.value / _filteredHistory.length * 100);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(entry.key)),
            Expanded(
              flex: 3,
              child: LinearProgressIndicator(
                value: entry.value / _filteredHistory.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  entry.key.startsWith('Low') ? Colors.green :
                  entry.key.startsWith('High') ? Colors.orange : Colors.blue,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// Supporting data classes
class CostDataPoint {
  final DateTime date;
  final double cost;
  final double weightedAverage;
  final int quantity;
  final double totalCost;

  CostDataPoint({
    required this.date,
    required this.cost,
    required this.weightedAverage,
    required this.quantity,
    required this.totalCost,
  });
}

class CumulativeDataPoint {
  final DateTime date;
  final double cumulativeCost;

  CumulativeDataPoint(this.date, this.cumulativeCost);
}

enum ChartType {
  timeline,
  quantity,
  cumulative,
}



class _CategoryEditDialogState extends State<CategoryEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _slugController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _slugController.text = widget.category!.slug;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  void _generateSlug() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      _slugController.text = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    }
  }

  void _saveCategory() {
    if (_formKey.currentState!.validate()) {
      final category = Category(
        id: widget.category?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        count: widget.category?.count ?? 0,
        imageUrl: widget.category?.imageUrl,
      );
      widget.onSave(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Category' : 'Add New Category',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Category Name *',
                  hintText: 'Enter category name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.category_rounded, color: Colors.blue.shade600),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter category name';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (widget.category == null) {
                    _generateSlug();
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slugController,
                decoration: InputDecoration(
                  labelText: 'Slug *',
                  hintText: 'category-slug',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.link_rounded, color: Colors.green.shade600),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter slug';
                  }
                  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                    return 'Slug can only contain lowercase letters, numbers, and hyphens';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter category description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.description_rounded, color: Colors.orange.shade600),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saveCategory,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(isEditing ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeleteConfirmationDialog extends StatelessWidget {
  final String itemName;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.itemName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_rounded,
                size: 32,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Category?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "$itemName"? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  _ProductManagementScreenState createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<Product> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final ValueNotifier<bool> _thisIsLoading = ValueNotifier(false);
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.sku.toLowerCase().contains(query) ||
            (product.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _loadProducts() async {
    final LocalDatabase localDb = LocalDatabase();
    try {
      List<Product> products;

      if (_posService.isOnline) {
        products = await _posService.fetchProducts(limit: 100);
      } else {
        products = await localDb.getAllProducts();
      }

      setState(() {
        _products.clear();
        _products.addAll(products);
        _filteredProducts = List.from(_products);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Professional Navigation Methods
  void _navigateToAddProduct() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AddProductScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) => _loadProducts());
  }

  void _navigateToEditProduct(Product product) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EditProductScreen(product: product),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) => _loadProducts());
  }

  void _navigateToRestockProduct() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RestockProductScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) => _loadProducts());
  }

  void _navigateToInventorySummary() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const InventorySummaryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

// Add these methods to your ProductManagementScreen class

  void _navigateToBulkScan() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const BulkScanScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // void _navigateToExport() {
  //   Navigator.push(
  //     context,
  //     PageRouteBuilder(
  //       pageBuilder: (context, animation, secondaryAnimation) => const ExportScreen(),
  //       transitionsBuilder: (context, animation, secondaryAnimation, child) {
  //         return FadeTransition(
  //           opacity: animation,
  //           child: child,
  //         );
  //       },
  //     ),
  //   );
  // }
  void _navigateToWacRestocking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestockProductScreen(),
      ),
    );
  }

// Update the _showAdvancedOptions method to use the new navigation
  void _showAdvancedOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              _buildBottomSheetItem(
                icon: Icons.summarize_rounded,
                title: 'Inventory Summary',
                subtitle: 'View analytics and reports',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToInventorySummary();
                },
              ),

              _buildBottomSheetItem(
                icon: Icons.category_rounded,
                title: 'Manage Categories',
                subtitle: 'Add or edit product categories',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCategoryManagement();
                },
              ),

              _buildBottomSheetItem(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Bulk Barcode Scan',
                subtitle: 'Scan multiple products quickly',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToBulkScan(); // already exists
                },
              ),

              /// ⭐ NEW OPTION ADDED HERE
              _buildBottomSheetItem(
                icon: Icons.inventory_2_rounded,
                title: 'Restock Using WAC',
                subtitle: 'Update stock using Weighted Average Cost',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToWacRestocking();  // <-- YOU MUST CREATE THIS METHOD
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildBottomSheetItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.blue.shade700),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  void _navigateToCategoryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
    );
  }



  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products by name, SKU...',
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: Colors.grey.shade500),
            onPressed: () {
              _searchController.clear();
              _filterProducts();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 16),
            Text(
              'Loading Products...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Products',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No Products Yet' : 'No Products Found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? 'Add your first product to get started'
                  : 'Try adjusting your search terms',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_searchController.text.isEmpty)
              FilledButton.icon(
                onPressed: _navigateToAddProduct,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Product'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return ProductManagementCard(
          onViewCostHistory: () {
            Navigator.push(context,MaterialPageRoute(builder: (context) => CostHistoryScreen(product: _filteredProducts[index])));
          },
          product: product,
          onEdit: () => _navigateToEditProduct(product),
          onDelete: () => _deleteProduct(product.id),
          onRestock: () => _showRestockDialog(product),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showAdvancedOptions(context),
            tooltip: 'More Options',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(child: _buildProductGrid()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddProduct,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  // Keep your existing _deleteProduct and _showRestockDialog methods...
  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _posService.deleteProduct(productId);
        _loadProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete product: $e')),
        );
      }
    }
  }

  void _showRestockDialog(Product product) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${product.stockQuantity}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to add',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _thisIsLoading,
            builder: (context, isLoading, _) {
              return TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  _thisIsLoading.value = true;
                  final quantity = int.tryParse(quantityController.text) ?? 0;
                  if (quantity > 0) {
                    try {
                      await _posService.restockProduct(product.id, quantity);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        _loadProducts();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Product restocked')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to restock: $e')),
                        );
                      }
                    }
                  }
                  _thisIsLoading.value = false;
                },
                child: isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Restock'),
              );
            },
          )
        ],
      ),
    );
  }
}

// Product Management Card
// Add WAC information to your product cards
class ProductManagementCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestock;
  final VoidCallback onViewCostHistory;

  const ProductManagementCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onRestock,
    required this.onViewCostHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Product image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    image: product.imageUrl != null
                        ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),

                      // WAC INFORMATION
                      if (product.purchasePrice != null) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Cost: ${Constants.CURRENCY_NAME}${product.purchasePrice!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Margin: ${product.profitMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.profitMargin >= 20
                                    ? Colors.green[700]
                                    : product.profitMargin >= 10
                                    ? Colors.orange[700]
                                    : Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          SizedBox(width: 16),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.stockQuantity > 10
                                  ? Colors.green[50]
                                  : product.stockQuantity > 0
                                  ? Colors.orange[50]
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: product.stockQuantity > 10
                                    ? Colors.green[100]!
                                    : product.stockQuantity > 0
                                    ? Colors.orange[100]!
                                    : Colors.red[100]!,
                              ),
                            ),
                            child: Text(
                              'Stock: ${product.stockQuantity}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: product.stockQuantity > 10
                                    ? Colors.green[700]
                                    : product.stockQuantity > 0
                                    ? Colors.orange[700]
                                    : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'cost_history',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text('Cost History'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'restock',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle, size: 20),
                          SizedBox(width: 8),
                          Text('Restock'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'cost_history':
                        onViewCostHistory();
                        break;
                      case 'restock':
                        onRestock();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                ),
              ],
            ),

            // INVENTORY VALUE
            if (product.purchasePrice != null && product.stockQuantity > 0)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Inventory Value:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${Constants.CURRENCY_NAME}${product.inventoryValue.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
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
}



// Add Product Screen
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _purchasePriceController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final List<Category> _categories = [];
  final List<String> _selectedCategoryIds = [];
  bool _isLoading = false;
  bool _isCheckingBarcode = false;
  String? _barcodeError;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _posService.getCategories();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      print('Failed to load categories: $e');
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<bool> _isBarcodeDuplicate(String barcode) async {
    if (barcode.isEmpty) return false;
    setState(() {
      _isCheckingBarcode = true;
      _barcodeError = null;
    });
    try {
      if (_posService.isOnline) {
        final onlineProducts = await _posService.searchProductsBySKU(barcode);
        if (onlineProducts.isNotEmpty) {
          return true;
        }
      }
      final LocalDatabase localDb = LocalDatabase();
      final localProduct = await localDb.getProductBySku(barcode);
      return localProduct != null;
    } catch (e) {
      print('Error checking barcode duplicate: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isCheckingBarcode = false);
      }
    }
  }

  Future<void> _scanAndSetBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'add',
    );
    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        _skuController.text = barcode;
        _barcodeError = null;
      });
      Future.delayed(Duration(milliseconds: 500), () {
        _validateBarcodeUniqueness(barcode);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode scanned: $barcode'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _validateBarcodeUniqueness(String barcode) async {
    if (barcode.isEmpty) return;
    final isDuplicate = await _isBarcodeDuplicate(barcode);
    if (mounted) {
      setState(() {
        if (isDuplicate) {
          _barcodeError = 'This barcode is already used by another product';
        } else {
          _barcodeError = null;
        }
      });
    }
  }

  Future<bool> _validateForm() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    final barcode = _skuController.text.trim();
    if (barcode.isNotEmpty) {
      final isDuplicate = await _isBarcodeDuplicate(barcode);
      if (isDuplicate) {
        setState(() {
          _barcodeError = 'This barcode is already used by another product';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please use a unique barcode'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitProduct() async {
    if (!await _validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final selectedCategories = _categories
          .where((cat) => _selectedCategoryIds.contains(cat.id))
          .toList();

      final product = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        sku: _skuController.text.trim(),
        price: double.parse(_priceController.text),
        purchasePrice: double.tryParse(_purchasePriceController.text),
        stockQuantity: int.parse(_stockController.text),
        inStock: true,
        stockStatus: 'instock',
        description: _descriptionController.text,
        status: 'publish',
        categories: selectedCategories,
      );

      await _posService.addProduct(product, _selectedImages);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        // GestureDetector(
        //   onTap: _pickImages,
        //   child: Container(
        //     height: 200,
        //     decoration: BoxDecoration(
        //       border: Border.all(color: Colors.grey),
        //       borderRadius: BorderRadius.circular(8),
        //     ),
        //     child: _selectedImages.isEmpty
        //         ? Column(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         Icon(
        //           Icons.add_photo_alternate,
        //           size: 50,
        //           color: Colors.grey,
        //         ),
        //         Text('Tap to add product images'),
        //         SizedBox(height: 4),
        //         Text(
        //           'Max 5 images',
        //           style: TextStyle(fontSize: 12, color: Colors.grey),
        //         ),
        //       ],
        //     )
        //         : Stack(
        //       children: [
        //         PageView.builder(
        //           itemCount: _selectedImages.length,
        //           itemBuilder: (context, index) {
        //             return Stack(
        //               children: [
        //                 Image.file(
        //                   File(_selectedImages[index].path),
        //                   fit: BoxFit.cover,
        //                 ),
        //                 Positioned(
        //                   top: 8,
        //                   right: 8,
        //                   child: Container(
        //                     decoration: BoxDecoration(
        //                       color: Colors.black54,
        //                       shape: BoxShape.circle,
        //                     ),
        //                     child: IconButton(
        //                       icon: Icon(
        //                         Icons.close,
        //                         color: Colors.white,
        //                         size: 20,
        //                       ),
        //                       onPressed: () => _removeImage(index),
        //                     ),
        //                   ),
        //                 ),
        //               ],
        //             );
        //           },
        //         ),
        //         if (_selectedImages.length < 5)
        //           Positioned(
        //             bottom: 8,
        //             right: 8,
        //             child: FloatingActionButton.small(
        //               onPressed: _pickImages,
        //               child: Icon(Icons.add),
        //             ),
        //           ),
        //       ],
        //     ),
        //   ),
        // ),
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedImages.length}/5 images selected. Tap image to remove.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        _isLoadingCategories
            ? CircularProgressIndicator()
            : _categories.isEmpty
            ? Text(
          'No categories available. Add categories in settings.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        )
            : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategoryIds.contains(category.id);
            return FilterChip(
              label: Text(category.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategoryIds.add(category.id);
                  } else {
                    _selectedCategoryIds.remove(category.id);
                  }
                });
              },
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[800],
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        if (_selectedCategoryIds.isNotEmpty)
          Text(
            'Selected: ${_selectedCategoryIds.length} categor${_selectedCategoryIds.length == 1 ? 'y' : 'ies'}',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _skuController,
          decoration: InputDecoration(
            labelText: 'SKU/Barcode',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.qr_code),
            suffixIcon: _isCheckingBarcode
                ? Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : IconButton(
              icon: Icon(Icons.qr_code_scanner),
              onPressed: _scanAndSetBarcode,
              tooltip: 'Scan Barcode',
            ),
            errorText: _barcodeError,
          ),
          onChanged: (value) {
            if (_barcodeError != null && value != _skuController.text) {
              setState(() => _barcodeError = null);
            }
            if (value.isNotEmpty && value.length >= 3) {
              Future.delayed(Duration(milliseconds: 1000), () {
                if (mounted && value == _skuController.text) {
                  _validateBarcodeUniqueness(value);
                }
              });
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter SKU or scan barcode';
            }
            if (_barcodeError != null) {
              return _barcodeError;
            }
            return null;
          },
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Barcode must be unique. We\'ll check for duplicates automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        if (_barcodeError != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _barcodeError!,
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: _isLoading
              ? ElevatedButton(
            onPressed: null,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          )
              : ElevatedButton(
            onPressed: _submitProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: _barcodeError != null ? Colors.grey : null,
            ),
            child: Text(
              'ADD PRODUCT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New Product')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildImagePickerSection(),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter product name' : null,
              ),
              SizedBox(height: 16),
              _buildCategorySelection(),
              SizedBox(height: 16),
              _buildBarcodeField(),
              SizedBox(height: 16),
              TextFormField(
                controller: _purchasePriceController,
                decoration: InputDecoration(
                  labelText: 'Purchase Price (Cost Price)',
                  border: OutlineInputBorder(),
                  prefixText: Constants.CURRENCY_NAME,
                  prefixIcon: Icon(Icons.money_off_csred),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purchase price';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Please enter a valid number';
                  if (parsed <= 0) return 'Purchase price must be greater than 0';
                  return null;
                },
              ),

              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Sale Price',
                  border: OutlineInputBorder(),
                  prefixText: Constants.CURRENCY_NAME,
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter price';
                  if (double.tryParse(value!) == null)
                    return 'Please enter valid price';
                  if (double.parse(value) <= 0)
                    return 'Price must be greater than 0';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true)
                    return 'Please enter stock quantity';
                  if (int.tryParse(value!) == null)
                    return 'Please enter valid quantity';
                  if (int.parse(value) < 0) return 'Stock cannot be negative';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Edit Product Screen
class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  final ImagePicker _imagePicker = ImagePicker();
  final List<Category> _categories = [];
  final List<String> _selectedCategoryIds = [];
  bool _isLoading = false;
  bool _isCheckingBarcode = false;
  String? _barcodeError;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadCategories();
  }

  void _initializeForm() {
    final product = widget.product;
    _nameController.text = product.name;
    _skuController.text = product.sku;
    _priceController.text = product.price.toStringAsFixed(0);
    _purchasePriceController.text = product.purchasePrice?.toStringAsFixed(0) ?? '';
    _stockController.text = product.stockQuantity.toString();
    _descriptionController.text = product.description ?? '';
    _existingImageUrls.addAll(product.imageUrls ?? []);

    // Initialize selected categories
    if (product.categories != null) {
      _selectedCategoryIds.addAll(product.categories!.map((cat) => cat.id).toList());
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _posService.getCategories();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      print('Failed to load categories: $e');
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<bool> _isBarcodeDuplicate(String barcode) async {
    if (barcode.isEmpty || barcode == widget.product.sku) return false;

    setState(() {
      _isCheckingBarcode = true;
      _barcodeError = null;
    });
    try {
      if (_posService.isOnline) {
        final onlineProducts = await _posService.searchProductsBySKU(barcode);
        if (onlineProducts.isNotEmpty) {
          return true;
        }
      }
      final LocalDatabase localDb = LocalDatabase();
      final localProduct = await localDb.getProductBySku(barcode);
      return localProduct != null && localProduct.id != widget.product.id;
    } catch (e) {
      print('Error checking barcode duplicate: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isCheckingBarcode = false);
      }
    }
  }

  Future<void> _scanAndSetBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'edit',
    );
    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        _skuController.text = barcode;
        _barcodeError = null;
      });
      Future.delayed(Duration(milliseconds: 500), () {
        _validateBarcodeUniqueness(barcode);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode scanned: $barcode'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _validateBarcodeUniqueness(String barcode) async {
    if (barcode.isEmpty || barcode == widget.product.sku) return;
    final isDuplicate = await _isBarcodeDuplicate(barcode);
    if (mounted) {
      setState(() {
        if (isDuplicate) {
          _barcodeError = 'This barcode is already used by another product';
        } else {
          _barcodeError = null;
        }
      });
    }
  }

  Future<bool> _validateForm() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    final barcode = _skuController.text.trim();
    if (barcode.isNotEmpty && barcode != widget.product.sku) {
      final isDuplicate = await _isBarcodeDuplicate(barcode);
      if (isDuplicate) {
        setState(() {
          _barcodeError = 'This barcode is already used by another product';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please use a unique barcode'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _updateProduct() async {
    if (!await _validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final selectedCategories = _categories
          .where((cat) => _selectedCategoryIds.contains(cat.id))
          .toList();

      final updatedProduct = Product(
        id: widget.product.id,
        name: _nameController.text,
        sku: _skuController.text.trim(),
        price: double.parse(_priceController.text),
        purchasePrice: double.tryParse(_purchasePriceController.text),
        stockQuantity: int.parse(_stockController.text),
        inStock: int.parse(_stockController.text) > 0,
        stockStatus: int.parse(_stockController.text) > 0 ? 'instock' : 'outofstock',
        description: _descriptionController.text,
        status: 'publish',
        categories: selectedCategories,
        imageUrls: _existingImageUrls,
      );

      await _posService.updateProduct(updatedProduct, _selectedImages);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePickerSection() {
    final allImages = [..._existingImageUrls, ..._selectedImages.map((xfile) => xfile.path)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        if (allImages.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allImages.length,
              itemBuilder: (context, index) {
                final isExistingImage = index < _existingImageUrls.length;
                final imageUrl = allImages[index];

                return Container(
                  width: 100,
                  height: 100,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      isExistingImage
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Image.file(File(imageUrl), fit: BoxFit.cover),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () {
                              if (isExistingImage) {
                                _removeExistingImage(index);
                              } else {
                                _removeImage(index - _existingImageUrls.length);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
        ],
        ElevatedButton.icon(
          onPressed: _pickImages,
          icon: Icon(Icons.add_photo_alternate),
          label: Text('Add Images'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[50],
            foregroundColor: Colors.blue[700],
          ),
        ),
        if (allImages.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '${allImages.length} images selected. Tap image to remove.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        _isLoadingCategories
            ? CircularProgressIndicator()
            : _categories.isEmpty
            ? Text(
          'No categories available. Add categories in settings.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        )
            : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategoryIds.contains(category.id);
            return FilterChip(
              label: Text(category.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategoryIds.add(category.id);
                  } else {
                    _selectedCategoryIds.remove(category.id);
                  }
                });
              },
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[800],
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        if (_selectedCategoryIds.isNotEmpty)
          Text(
            'Selected: ${_selectedCategoryIds.length} categor${_selectedCategoryIds.length == 1 ? 'y' : 'ies'}',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _skuController,
          decoration: InputDecoration(
            labelText: 'SKU/Barcode',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.qr_code),
            suffixIcon: _isCheckingBarcode
                ? Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : IconButton(
              icon: Icon(Icons.qr_code_scanner),
              onPressed: _scanAndSetBarcode,
              tooltip: 'Scan Barcode',
            ),
            errorText: _barcodeError,
          ),
          onChanged: (value) {
            if (_barcodeError != null && value != widget.product.sku) {
              setState(() => _barcodeError = null);
            }
            if (value.isNotEmpty && value != widget.product.sku && value.length >= 3) {
              Future.delayed(Duration(milliseconds: 1000), () {
                if (mounted && value == _skuController.text) {
                  _validateBarcodeUniqueness(value);
                }
              });
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter SKU or scan barcode';
            }
            if (_barcodeError != null) {
              return _barcodeError;
            }
            return null;
          },
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Changing barcode? We\'ll check for duplicates automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
    return Column(
      children: [
        if (_barcodeError != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _barcodeError!,
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: _isLoading
              ? ElevatedButton(
            onPressed: null,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          )
              : ElevatedButton(
            onPressed: _updateProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: _barcodeError != null ? Colors.grey : Colors.green,
            ),
            child: Text(
              'UPDATE PRODUCT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Product'),
        backgroundColor: Colors.orange[50],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildImagePickerSection(),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter product name' : null,
              ),
              SizedBox(height: 16),
              _buildCategorySelection(),
              SizedBox(height: 16),
              _buildBarcodeField(),
              SizedBox(height: 16),
              TextFormField(
                controller: _purchasePriceController,
                decoration: InputDecoration(
                  labelText: 'Purchase Price (Cost Price)',
                  border: OutlineInputBorder(),
                  prefixText: Constants.CURRENCY_NAME,
                  prefixIcon: Icon(Icons.money_off_csred),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purchase price';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Please enter a valid number';
                  if (parsed <= 0) return 'Purchase price must be greater than 0';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Sale Price',
                  border: OutlineInputBorder(),
                  prefixText: Constants.CURRENCY_NAME,
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter price';
                  if (double.tryParse(value!) == null)
                    return 'Please enter valid price';
                  if (double.parse(value) <= 0)
                    return 'Price must be greater than 0';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true)
                    return 'Please enter stock quantity';
                  if (int.tryParse(value!) == null)
                    return 'Please enter valid quantity';
                  if (int.parse(value) < 0) return 'Stock cannot be negative';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              _buildUpdateButton(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}


class RestockProductScreen extends StatefulWidget {
  const RestockProductScreen({super.key});

  @override
  _RestockProductScreenState createState() => _RestockProductScreenState();
}

class _RestockProductScreenState extends State<RestockProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Product> _allProducts = [];
  Product? _selectedProduct;
  bool _isScanning = false;
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _purchasePriceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    _purchasePriceController.text = '';
    _supplierController.text = '';
    _notesController.text = '';

    _loadAllProducts();
  }

  @override
  void dispose() {
    _quantityFocusNode.dispose();
    _purchasePriceFocusNode.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAllProducts() async {
    setState(() => _isLoadingProducts = true);
    final LocalDatabase localDb = LocalDatabase();
    try {
      List<Product> products;

      if (_posService.isOnline) {
        products = await _posService.fetchProducts(limit: 1000);
      } else {
        products = await localDb.getAllProducts();
      }

      setState(() {
        _allProducts.clear();
        _allProducts.addAll(products);
      });
    } catch (e) {
      print('Failed to load products: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _scanBarcode() async {
    setState(() => _isScanning = true);
    try {
      final barcode = await UniversalScanningService.scanBarcode(
        context,
        purpose: 'restock',
      );
      if (barcode != null && barcode.isNotEmpty) {
        _barcodeController.text = barcode;
        await _searchProductByBarcode(barcode);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _searchProductByBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      List<Product> products = await _posService.searchProductsBySKU(barcode);

      if (products.isEmpty) {
        print('Primary search failed, trying local search...');
        products = _allProducts.where((p) => p.sku == barcode).toList();
      }

      if (products.isNotEmpty) {
        final product = products.first;
        setState(() {
          _selectedProduct = product;
        });

        _quantityController.text = '1';
        _purchasePriceController.text = product.purchasePrice?.toStringAsFixed(2) ?? '';
        FocusScope.of(context).requestFocus(_quantityFocusNode);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product found: ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _selectedProduct = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found with barcode: $barcode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _selectedProduct = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restockProduct() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a product first')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid quantity')),
      );
      return;
    }

    if (purchasePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid purchase price')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _posService.restockProductWithWAC(
        _selectedProduct!.id,
        quantity,
        purchasePrice,
        supplier: _supplierController.text.isEmpty ? null : _supplierController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (_posService.isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedProduct!.name} restocked with $quantity items!\n'
                  'Weighted average cost updated.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadAllProducts();
        _clearSelection();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadAllProducts();
      // Navigator.of(context).pop();
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('offline') || errorMessage.contains('Saved offline')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadAllProducts();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProduct = null;
      _barcodeController.clear();
      _quantityController.text = '1';
      _purchasePriceController.text = '';
      _supplierController.clear();
      _notesController.clear();
    });
  }

  int get _newStockQuantity {
    final currentStock = _selectedProduct?.stockQuantity ?? 0;
    final addedQuantity = int.tryParse(_quantityController.text) ?? 0;
    return currentStock + addedQuantity;
  }

  double get _totalPurchaseCost {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
    return quantity * purchasePrice;
  }

  bool get _canRestock {
    return _selectedProduct != null &&
        _quantityController.text.isNotEmpty &&
        (int.tryParse(_quantityController.text) ?? 0) > 0 &&
        _purchasePriceController.text.isNotEmpty &&
        (double.tryParse(_purchasePriceController.text) ?? 0) > 0;
  }

  Widget _buildWACInformation() {
    if (_selectedProduct == null) return SizedBox();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Weighted Average Cost',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_selectedProduct!.purchasePrice != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current WAC:'),
                  Text(
                    '${Constants.CURRENCY_NAME}${_selectedProduct!.purchasePrice!.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profit Margin:'),
                  Text(
                    '${_selectedProduct!.profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _selectedProduct!.profitMargin >= 20
                          ? Colors.green
                          : _selectedProduct!.profitMargin >= 10
                          ? Colors.orange
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Inventory Value:'),
                  Text(
                    '${Constants.CURRENCY_NAME}${_selectedProduct!.inventoryValue.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('This Purchase:'),
                  Text(
                    '${Constants.CURRENCY_NAME}${_totalPurchaseCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'No purchase history yet. This will set the initial cost.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasePriceSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Purchase Price (Cost)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _purchasePriceController,
              focusNode: _purchasePriceFocusNode,
              decoration: InputDecoration(
                labelText: 'Cost per Unit',
                border: OutlineInputBorder(),
                prefixText: Constants.CURRENCY_NAME,
                hintText: 'Enter purchase price',
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _purchasePriceController.clear();
                    setState(() {});
                  },
                ),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                setState(() {});
              },
            ),
            SizedBox(height: 8),
            if (_selectedProduct != null && _selectedProduct!.purchasePrice != null)
              Text(
                'Current Weighted Average Cost: ${Constants.CURRENCY_NAME}${_selectedProduct!.purchasePrice!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierAndNotesSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Additional Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: 'Supplier (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_center),
                hintText: 'Enter supplier name',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                hintText: 'Add any notes about this purchase',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualProductSelection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Select Product Manually',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
      DropdownButtonFormField<Product>(
        value: _selectedProduct,
        isExpanded: true,

        decoration: InputDecoration(
          labelText: "Choose Product",
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),

        /// 🔥 FIX: compact view for selected item
        selectedItemBuilder: (context) {
          return _allProducts.map((product) {
            return Text(
              product.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList();
        },

        /// Full detailed view inside dropdown menu
        items: _allProducts.map((product) {
          return DropdownMenuItem<Product>(
            value: product,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    "SKU: ${product.sku}   •   Stock: ${product.stockQuantity}",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  if (product.purchasePrice != null) ...[
                    SizedBox(height: 2),
                    Text(
                      "WAC: ${Constants.CURRENCY_NAME}${product.purchasePrice!.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),

        onChanged: (product) {
          setState(() {
            _selectedProduct = product;

            if (product != null) {
              _barcodeController.text = product.sku;
              _quantityController.text = "1";
              _purchasePriceController.text =
                  product.purchasePrice?.toStringAsFixed(2) ?? "";
              FocusScope.of(context).requestFocus(_quantityFocusNode);
            }
          });
        },
      )],
        ),
      ),
    );
  }

  Widget _buildBarcodeInputSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Scan Barcode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barcode/SKU',
                      border: OutlineInputBorder(),
                      suffixIcon: _isLoading
                          ? Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : _barcodeController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _barcodeController.clear();
                          setState(() {});
                        },
                      )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      if (value.length >= 3) {
                        _searchProductByBarcode(value);
                      }
                    },
                  ),
                ),
                SizedBox(width: 12),
                _isScanning
                    ? CircularProgressIndicator()
                    : IconButton(
                  icon: Icon(
                    Icons.qr_code_scanner,
                    size: 32,
                  ),
                  onPressed: _scanBarcode,
                  tooltip: 'Scan Barcode',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    padding: EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
            if (_barcodeController.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Press scan button or enter to search',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfoSection() {
    if (_selectedProduct == null) return SizedBox();

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Selected Product',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    image: _selectedProduct!.imageUrl != null
                        ? DecorationImage(
                      image: NetworkImage(
                        _selectedProduct!.imageUrl!,
                      ),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _selectedProduct!.imageUrl == null
                      ? Icon(
                    Icons.inventory,
                    color: Colors.grey[400],
                  )
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedProduct!.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'SKU: ${_selectedProduct!.sku}',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Current Stock: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _selectedProduct!.stockQuantity.toString(),
                            style: TextStyle(
                              color: _selectedProduct!.inStock
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Sale Price: ${Constants.CURRENCY_NAME}${_selectedProduct!.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityInputSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Restock Quantity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              focusNode: _quantityFocusNode,
              decoration: InputDecoration(
                labelText: 'Quantity to Add',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add),
                hintText: 'Enter quantity',
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _quantityController.text = '1';
                    setState(() {});
                  },
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {});
              },
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Total Stock:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$_newStockQuantity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Restock Product (WAC)'),
        actions: [
          if (_selectedProduct != null)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear Selection',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllProducts,
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: _isLoadingProducts
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildManualProductSelection(),
            SizedBox(height: 16),

            // OR Divider
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            SizedBox(height: 16),

            _buildBarcodeInputSection(),
            SizedBox(height: 16),

            if (_selectedProduct != null) ...[
              _buildProductInfoSection(),
              SizedBox(height: 16),
              _buildWACInformation(),
              SizedBox(height: 16),
              _buildQuantityInputSection(),
              SizedBox(height: 16),
              _buildPurchasePriceSection(),
              SizedBox(height: 16),
              _buildSupplierAndNotesSection(),
              SizedBox(height: 24),
            ],

            // Restock Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? ElevatedButton(
                onPressed: null,
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
                  : ElevatedButton(
                onPressed: _canRestock ? _restockProduct : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canRestock ? Colors.green : Colors.grey,
                ),
                child: Text(
                  'RESTOCK WITH WAC',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
// inventory_summary_base.dart
class InventorySummary {
  final DateTime generatedAt;
  final List<Product> products;
  final List<Category> categories;
  final Map<String, dynamic> statistics;

  InventorySummary({
    required this.generatedAt,
    required this.products,
    required this.categories,
    required this.statistics,
  });

  double get totalInventoryValue {
    return products.fold(0.0, (sum, product) => sum + (product.price * product.stockQuantity));
  }

  double get totalCostValue {
    return products.fold(0.0, (sum, product) {
      final cost = product.purchasePrice ?? product.price * 0.7; // Default 70% of sale price
      return sum + (cost * product.stockQuantity);
    });
  }

  int get totalStockQuantity {
    return products.fold(0, (sum, product) => sum + product.stockQuantity);
  }

  int get outOfStockCount {
    return products.where((product) => product.stockQuantity == 0).length;
  }

  int get lowStockCount {
    return products.where((product) => product.stockQuantity > 0 && product.stockQuantity <= 10).length;
  }

  Map<String, int> get categoryDistribution {
    final distribution = <String, int>{};
    for (final product in products) {
      if (product.categories != null && product.categories!.isNotEmpty) {
        for (final category in product.categories!) {
          distribution[category.name] = (distribution[category.name] ?? 0) + product.stockQuantity;
        }
      } else {
        distribution['Uncategorized'] = (distribution['Uncategorized'] ?? 0) + product.stockQuantity;
      }
    }
    return distribution;
  }
}


class InventorySummaryScreen extends StatefulWidget {
  const InventorySummaryScreen({super.key});

  @override
  _InventorySummaryScreenState createState() => _InventorySummaryScreenState();
}

class _InventorySummaryScreenState extends State<InventorySummaryScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final LocalDatabase _localDb = LocalDatabase();
  InventorySummary? _summary;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadInventorySummary();
  }

  Future<void> _loadInventorySummary() async {
    setState(() => _isLoading = true);
    try {
      List<Product> products;
      List<Category> categories;

      if (_posService.isOnline) {
        products = await _posService.fetchProducts(limit: 1000);
        categories = await _posService.getCategories();
      } else {
        products = await _localDb.getAllProducts();
        categories = await _localDb.getAllCategories();
      }

      final statistics = {
        'totalProducts': products.length,
        'totalCategories': categories.length,
        'totalValue': products.fold(0.0, (sum, p) => sum + (p.price * p.stockQuantity)),
        'totalCost': products.fold(0.0, (sum, p) => sum + ((p.purchasePrice ?? p.price * 0.7) * p.stockQuantity)),
        'totalStock': products.fold(0, (sum, p) => sum + p.stockQuantity),
        'outOfStock': products.where((p) => p.stockQuantity == 0).length,
        'lowStock': products.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 10).length,
      };

      setState(() {
        _summary = InventorySummary(
          generatedAt: DateTime.now(),
          products: products,
          categories: categories,
          statistics: statistics,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load inventory summary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAndViewPdf() async {
    if (_summary == null) return;

    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = await _generatePdf(_summary!);
      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_summary == null) return;

    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = await _generatePdf(_summary!);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'inventory-summary-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  Future<pw.Document> _generatePdf(InventorySummary summary) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildPdfHeader(font, fontBold),
          _buildPdfStatistics(summary, font, fontBold),
          _buildPdfCategoryBreakdown(summary, font, fontBold),
          _buildPdfLowStockItems(summary, font, fontBold),
          _buildPdfProductList(summary, font, fontBold),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfHeader(pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INVENTORY SUMMARY REPORT',
          style: pw.TextStyle(font: fontBold, fontSize: 24),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 12),
        ),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfStatistics(InventorySummary summary, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Key Statistics', style: pw.TextStyle(font: fontBold, fontSize: 16)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Products', summary.products.length.toString(), font, fontBold),
              _buildStatItem('Total Categories', summary.categories.length.toString(), font, fontBold),
              _buildStatItem('Total Stock', summary.totalStockQuantity.toString(), font, fontBold),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Out of Stock', summary.outOfStockCount.toString(), font, fontBold),
              _buildStatItem('Low Stock', summary.lowStockCount.toString(), font, fontBold),
              _buildStatItem('Inventory Value', '${Constants.CURRENCY_NAME}${summary.totalInventoryValue.toStringAsFixed(0)}', font, fontBold),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatItem(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 14)),
      ],
    );
  }

  pw.Widget _buildPdfCategoryBreakdown(InventorySummary summary, pw.Font font, pw.Font fontBold) {
    final distribution = summary.categoryDistribution;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Category Distribution', style: pw.TextStyle(font: fontBold, fontSize: 16)),
          pw.SizedBox(height: 12),
          ...distribution.entries.map((entry) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(entry.key, style: pw.TextStyle(font: font)),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(
                    height: 20,
                    child: pw.Stack(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                        ),
                        pw.Container(
                          width: (entry.value / summary.totalStockQuantity) * 200,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue400,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  '${entry.value} (${((entry.value / summary.totalStockQuantity) * 100).toStringAsFixed(1)}%)',
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  pw.Widget _buildPdfLowStockItems(InventorySummary summary, pw.Font font, pw.Font fontBold) {
    final lowStockItems = summary.products
        .where((p) => p.stockQuantity <= 10)
        .toList()
      ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

    if (lowStockItems.isEmpty) return pw.SizedBox();

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Low Stock Alert (≤ 10 items)', style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.red)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Product', style: pw.TextStyle(font: fontBold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('SKU', style: pw.TextStyle(font: fontBold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Stock', style: pw.TextStyle(font: fontBold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Status', style: pw.TextStyle(font: fontBold)),
                  ),
                ],
              ),
              ...lowStockItems.map((product) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.name, style: pw.TextStyle(font: font)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.sku, style: pw.TextStyle(font: font)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(product.stockQuantity.toString(), style: pw.TextStyle(font: font)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      product.stockQuantity == 0 ? 'OUT OF STOCK' : 'LOW STOCK',
                      style: pw.TextStyle(
                        font: fontBold,
                        color: product.stockQuantity == 0 ? PdfColors.red : PdfColors.orange,
                      ),
                    ),
                  ),
                ],
              )).toList(),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfProductList(InventorySummary summary, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Complete Product List', style: pw.TextStyle(font: fontBold, fontSize: 16)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Product', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('SKU', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Price', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Stock', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Value', style: pw.TextStyle(font: fontBold, fontSize: 10))),
                ],
              ),
              ...summary.products.take(100).map((product) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(product.name, style: pw.TextStyle(font: font, fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(product.sku, style: pw.TextStyle(font: font, fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(product.stockQuantity.toString(), style: pw.TextStyle(font: font, fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${Constants.CURRENCY_NAME}${(product.price * product.stockQuantity).toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 8)),
                  ),
                ],
              )).toList(),
            ],
          ),
          if (summary.products.length > 100)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                '... and ${summary.products.length - 100} more products',
                style: pw.TextStyle(font: font, fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_summary == null) return SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Inventory Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard(
                  'Total Products',
                  _summary!.products.length.toString(),
                  Icons.inventory_2,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Total Stock',
                  _summary!.totalStockQuantity.toString(),
                  Icons.warehouse,
                  Colors.green,
                ),
                _buildStatCard(
                  'Inventory Value',
                  '${Constants.CURRENCY_NAME}${_summary!.totalInventoryValue.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Out of Stock',
                  _summary!.outOfStockCount.toString(),
                  Icons.error_outline,
                  Colors.red,
                ),
                _buildStatCard(
                  'Low Stock',
                  _summary!.lowStockCount.toString(),
                  Icons.warning_amber,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Categories',
                  _summary!.categories.length.toString(),
                  Icons.category,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    if (_summary == null) return SizedBox();

    final distribution = _summary!.categoryDistribution;
    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock by Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sortedEntries.take(10).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(entry.key),
                  ),
                  Expanded(
                    flex: 5,
                    child: LinearProgressIndicator(
                      value: entry.value / _summary!.totalStockQuantity,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    if (_summary == null) return SizedBox();

    final lowStockItems = _summary!.products
        .where((p) => p.stockQuantity <= 10)
        .toList()
      ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

    if (lowStockItems.isEmpty) return SizedBox();

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[800]),
                const SizedBox(width: 8),
                const Text(
                  'Low Stock Alert',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lowStockItems.take(5).map((product) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.imageUrl != null
                    ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                    : Icon(Icons.inventory_2, color: Colors.grey[400]),
              ),
              title: Text(product.name),
              subtitle: Text('SKU: ${product.sku}'),
              trailing: Chip(
                label: Text(
                  '${product.stockQuantity} left',
                  style: TextStyle(
                    color: product.stockQuantity == 0 ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: product.stockQuantity == 0 ? Colors.red[50] : Colors.orange[50],
              ),
            )).toList(),
            if (lowStockItems.length > 5)
              Text(
                '... and ${lowStockItems.length - 5} more items',
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Summary'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventorySummary,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pdf') _generateAndViewPdf();
              if (value == 'share') _sharePdf();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Generate PDF')),
              const PopupMenuItem(value: 'share', child: Text('Share Report')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
          ? const Center(child: Text('No inventory data available'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatisticsCard(),
            const SizedBox(height: 16),
            _buildLowStockAlert(),
            const SizedBox(height: 16),
            _buildCategoryDistribution(),
            const SizedBox(height: 16),
            if (_isGeneratingPdf)
              const LinearProgressIndicator(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateAndViewPdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Generate PDF'),
        backgroundColor: Colors.red,
      ),
    );
  }
}