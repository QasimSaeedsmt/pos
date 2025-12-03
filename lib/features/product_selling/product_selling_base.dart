import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mpcm/core/overlay_manager.dart';
import 'package:mpcm/theme_utils.dart';

import '../../constants.dart';
import '../../core/models/category_model.dart';
import '../../core/models/product_model.dart';
import '../cartBase/cart_base.dart';
import '../invoiceBase/invoice_and_printing_base.dart';
import '../main_navigation/main_navigation_base.dart';
// Add this new class for tracking individual restocks
class PurchaseRecord {
  final String id;
  final String productId;
  final String productName;
  final String productSku;
  final int quantity;
  final double purchasePrice; // Cost per unit for THIS batch
  final double totalCost; // quantity * purchasePrice
  final DateTime purchaseDate;
  final String? supplier;
  final String? batchNumber;
  final String? notes;

  PurchaseRecord({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.purchasePrice,
    required this.totalCost,
    required this.purchaseDate,
    this.supplier,
    this.batchNumber,
    this.notes,
  });

  factory PurchaseRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return PurchaseRecord(
      id: id,
      productId: data['productId']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      productSku: data['productSku']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      totalCost: (data['totalCost'] as num?)?.toDouble() ?? 0.0,
      purchaseDate: data['purchaseDate'] is Timestamp
          ? (data['purchaseDate'] as Timestamp).toDate()
          : DateTime.now(),
      supplier: data['supplier']?.toString(),
      batchNumber: data['batchNumber']?.toString(),
      notes: data['notes']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productSku': productSku,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'totalCost': totalCost,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'supplier': supplier,
      'batchNumber': batchNumber,
      'notes': notes,
    };
  }
}
class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final List<String> imageUrls;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;

  const ProductImage({
    super.key,
    this.imageUrl,
    this.imageUrls = const [],
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveImageUrl = _getEffectiveImageUrl();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: _buildImageContent(effectiveImageUrl),
      ),
    );
  }

  String? _getEffectiveImageUrl() {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    if (imageUrls.isNotEmpty) return imageUrls.first;
    return null;
  }

  Widget _buildImageContent(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Image.asset(
        'assets/product-placeholder.jpeg',
        fit: BoxFit.cover,
        width: width,
        height: height,
      );
    }

    return Image.network(
      imageUrl,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Stack(
          children: [
            Image.asset(
              'assets/product-placeholder.jpeg',
              fit: BoxFit.cover,
              width: width,
              height: height,
            ),
            Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/product-placeholder.jpeg',
          fit: BoxFit.cover,
          width: width,
          height: height,
        );
      },
    );
  }
}

class ProductSellingScreen extends StatefulWidget {
  final EnhancedCartManager cartManager;

  const ProductSellingScreen({super.key, required this.cartManager});

  @override
  _ProductSellingScreenState createState() => _ProductSellingScreenState();
}

class _ProductSellingScreenState extends State<ProductSellingScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final TextEditingController _searchController = TextEditingController();
  final List<Product> _products = [];
  final List<Product> _filteredProducts = [];
  final List<Product> _recentProducts = [];
  final List<Category> _categories = [];
  String _selectedCategoryId = 'all';
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchError = '';
  Timer? _searchDebounce;
  int _cartItemCount = 0;
  bool _inStockOnly = false;
  bool _usePOSMode = false;

  bool get _isDesktop {
    if (kIsWeb) {
      final mediaQuery = MediaQuery.of(context);
      return mediaQuery.size.width > 768;
    }
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _setupCartListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDesktop && mounted) {
        setState(() {
          _usePOSMode = true;
        });
      }
    });
  }

  void _setupCartListener() {
    widget.cartManager.itemCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _cartItemCount = count;
        });
      }
    });
  }

  Future<void> _initializeScreen() async {
    await _loadProducts();
    await _loadCategories();
    await _loadRecentProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _searchError = '';
    });
    try {
      final products = await _posService.fetchProducts(
        limit: 100,
        inStockOnly: _inStockOnly,
      );
      if (!mounted) return;

      setState(() {
        _products.clear();
        _products.addAll(products);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _posService.getCategories();
      if (!mounted) return;

      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  Future<void> _loadRecentProducts() async {
    try {
      final recentProducts = await _posService.fetchProducts(limit: 10);
      setState(() {
        _recentProducts.clear();
        _recentProducts.addAll(recentProducts.take(8));
      });
    } catch (e) {
      debugPrint('Failed to load recent products: $e');
    }
  }

  void _onSearchTextChanged(String query) {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _applyFilters();
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query) {
    try {
      final searchQuery = query.toLowerCase().trim();

      final results = _products.where((product) {
        if (product.name.toLowerCase().contains(searchQuery)) return true;
        if (product.sku.toLowerCase().contains(searchQuery)) return true;
        for (final category in product.categories) {
          if (category.name.toLowerCase().contains(searchQuery)) return true;
        }
        if (product.description?.toLowerCase().contains(searchQuery) == true) return true;
        return false;
      }).toList();

      setState(() {
        _filteredProducts.clear();
        _filteredProducts.addAll(results);
        _searchError = '';
      });
    } catch (e) {
      setState(() {
        _searchError = 'Search failed: $e';
      });
    }
  }

  void _applyFilters() {
    final stopwatch = Stopwatch()..start();

    List<Product> filtered = List.from(_products);

    if (_selectedCategoryId != 'all') {
      filtered = filtered.where((product) {
        return product.categories.any((category) => category.id == _selectedCategoryId);
      }).toList();
    }

    if (_inStockOnly) {
      filtered = filtered.where((product) => product.inStock).toList();
    }

    setState(() {
      _filteredProducts.clear();
      _filteredProducts.addAll(filtered);
    });

    stopwatch.stop();
    debugPrint('Filter applied in ${stopwatch.elapsedMicroseconds} microseconds');
  }

  Future<void> _addToCart(Product product) async {
    try {
      await widget.cartManager.addToCart(product);

      showSmartSnackBar(
        context,
        '${product.name} added to cart',
        color: Colors.green,
      );
    } catch (e) {
      showSmartSnackBar(
        context,
        e.toString(),
        color: Colors.red,
      );
    }
  }

  Future<void> _scanAndAddProduct() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'sell',
    );
    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _searchError = '';
      });
      try {
        final products = await _posService.searchProductsBySKU(barcode);
        if (products.isNotEmpty) {
          final product = products.first;
          await _addToCart(product);
          _searchController.text = product.name;
          _onSearchTextChanged(product.name);
        } else {
         OverlayManager.showError(context, 'No product found with barcode: $barcode');
        }
      } catch (e) {
        OverlayManager.showError(context, 'Search failed: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void showSmartSnackBar(BuildContext context, String message, {Color? color}) {
    OverlayManager.showToast(
      context: context,
      message: message,
      backgroundColor: color ?? Colors.green,
      duration: const Duration(seconds: 2),
    );
  }
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _applyFilters();
    });
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductDetailBottomSheet(
        product: product,
        onAddToCart: () => _addToCart(product),
      ),
    );
  }

  void _toggleSellingMode() {
    setState(() {
      _usePOSMode = !_usePOSMode;
    });
  }

  void _showPOSProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => POSProductSelectionSheet(
        products: _products,
        cartManager: widget.cartManager,
        onProductAdded: _addToCart,
      ),
    );
  }

  Widget _buildProductGrid() {
    final displayProducts = _isSearching ? _filteredProducts : _filteredProducts;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products...'),
          ],
        ),
      );
    }

    if (_searchError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(_searchError, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _loadProducts, child: Text('Retry')),
          ],
        ),
      );
    }

    if (displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              _isSearching ? 'No products found' : 'No products available',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              _isSearching
                  ? 'Try a different search term or filter'
                  : 'Check your connection or product setup',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _isDesktop ? 4 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: _isDesktop ? 0.8 : 0.75,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        return ProductCard(
          product: product,
          onTap: () => _showProductDetails(product),
          onAddToCart: () => _addToCart(product),
        );
      },
    );
  }

  Widget _buildRecentProducts() {
    if (_recentProducts.isEmpty || _isSearching) return SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frequently Sold',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 20),
                onPressed: _loadRecentProducts,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8),
            itemCount: _recentProducts.length,
            itemBuilder: (context, index) {
              final product = _recentProducts[index];
              return Container(
                width: 120,
                margin: EdgeInsets.symmetric(horizontal: 4),
                child: RecentProductCard(
                  product: product,
                  onTap: () => _addToCart(product),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPOSModeInterface() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              Icon(Icons.point_of_sale, color: Colors.blue[700]),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'POS Mode Active - Professional desktop interface for quick product entry',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!_isDesktop)
                OutlinedButton(
                  onPressed: _toggleSellingMode,
                  child: Text('Switch to Grid Mode'),
                ),
            ],
          ),
        ),
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 350,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products by name or SKU...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                            : null,
                      ),
                      onChanged: _onSearchTextChanged,
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.qr_code_scanner,
                                color: Colors.blue[700],
                              ),
                              onPressed: _scanAndAddProduct,
                              tooltip: 'Scan Barcode',
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ),
              if (_selectedCategoryId != 'all' || _inStockOnly)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_selectedCategoryId != 'all')
                        Chip(
                          label: Text(
                            'Category: ${_categories.firstWhere(
                                  (cat) => cat.id == _selectedCategoryId,
                              orElse: () => Category(id: '', name: 'Unknown', slug: '', count: 0),
                            ).name}',
                          ),
                          deleteIcon: Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _selectedCategoryId = 'all';
                              _applyFilters();
                            });
                          },
                        ),
                      if (_inStockOnly)
                        Chip(
                          label: Text('In Stock Only'),
                          deleteIcon: Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _inStockOnly = false;
                              _applyFilters();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              _buildRecentProducts(),
            ],
          ),
        ),
        Expanded(
          child: _usePOSMode
              ? _buildPOSModeInterface()
              : Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.point_of_sale),
                      label: Text('POS Mode'),
                      onPressed: _toggleSellingMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildProductGrid()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products by name or SKU...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                        : null,
                  ),
                  onChanged: _onSearchTextChanged,
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.qr_code_scanner, color: Colors.blue[700]),
                  onPressed: _scanAndAddProduct,
                  tooltip: 'Scan Barcode',
                ),
              ),
            ],
          ),
        ),
        if (_selectedCategoryId != 'all' || _inStockOnly)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_selectedCategoryId != 'all')
                  Chip(
                    label: Text(
                      'Category: ${_categories.firstWhere(
                            (cat) => cat.id == _selectedCategoryId,
                        orElse: () => Category(id: '', name: 'Unknown', slug: '', count: 0),
                      ).name}',
                    ),
                    deleteIcon: Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoryId = 'all';
                        _applyFilters();
                      });
                    },
                  ),
                if (_inStockOnly)
                  Chip(
                    label: Text('In Stock Only'),
                    deleteIcon: Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _inStockOnly = false;
                        _applyFilters();
                      });
                    },
                  ),
              ],
            ),
          ),
        _buildRecentProducts(),
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[];

    if (_isDesktop) {
      actions.addAll([
        IconButton(
          icon: Icon(_usePOSMode ? Icons.grid_view : Icons.point_of_sale),
          onPressed: _toggleSellingMode,
          tooltip: _usePOSMode ? 'Switch to Grid Mode' : 'Switch to POS Mode',
        ),
      ]);
    }

    if (_isDesktop) {
      actions.add(
        IconButton(
          icon: Icon(Icons.add_circle_outline),
          onPressed: _showPOSProductSheet,
          tooltip: 'Quick Add Products',
        ),
      );
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final EnhancedCartManager cartManager = EnhancedCartManager();
    return Scaffold(
      appBar: _isDesktop ? AppBar(
        title: Text('Sell Products'),
        actions: _buildAppBarActions(),
      ) : null,
      body: _isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),

    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class POSProductSelectionSheet extends StatefulWidget {
  final List<Product> products;
  final EnhancedCartManager cartManager;
  final Function(Product) onProductAdded;

  const POSProductSelectionSheet({
    super.key,
    required this.products,
    required this.cartManager,
    required this.onProductAdded,
  });

  @override
  _POSProductSelectionSheetState createState() =>
      _POSProductSelectionSheetState();
}

class _POSProductSelectionSheetState extends State<POSProductSelectionSheet> {
  final List<POSProductRow> _productRows = [POSProductRow()];
  final Map<int, FocusNode> _focusNodes = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, List<Product>> _searchResults = {};
  final Map<int, Product?> _selectedProducts = {};

  @override
  void initState() {
    super.initState();
    _initializeFirstRow();
  }

  Future<void> _addAllToCart() async {
    int addedCount = 0;
    final List<String> errors = [];

    for (int i = 0; i < _productRows.length; i++) {
      final product = _selectedProducts[i];
      final row = _productRows[i];

      if (product != null && row.quantity > 0) {
        try {
          final effectivePrice = row.customPrice ?? product.price;
          final productToAdd = product.copyWith(price: effectivePrice);

          for (int j = 0; j < row.quantity; j++) {
            await widget.cartManager.addToCart(productToAdd);
          }
          addedCount += row.quantity;
        } catch (e) {
          errors.add('${product.name}: $e');
          debugPrint('Error adding product to cart: $e');
        }
      }
    }

    if (addedCount > 0) {
      String message = '$addedCount items added to cart';
      if (errors.isNotEmpty) {
        message += ' (${errors.length} errors)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: errors.isNotEmpty ? Colors.orange : Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      if (errors.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Some Items Could Not Be Added'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('The following items encountered issues:'),
                    SizedBox(height: 12),
                    ...errors
                        .map(
                          (error) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $error',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                        ,
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        });
      }

      Navigator.pop(context);
    } else {
      String errorMessage = 'No valid products to add';
      if (errors.isNotEmpty) {
        errorMessage += '. ${errors.join(", ")}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _initializeFirstRow() {
    _focusNodes[0] = FocusNode();
    _controllers[0] = TextEditingController();
    _searchResults[0] = [];
    _selectedProducts[0] = null;

    _focusNodes[0]!.addListener(() {
      if (!_focusNodes[0]!.hasFocus && _controllers[0]!.text.isEmpty) {
        _searchResults[0]!.clear();
        setState(() {});
      }
    });
  }

  void _onProductSearchChanged(int index, String query) {
    if (query.isEmpty) {
      _searchResults[index]!.clear();
      setState(() {});
      return;
    }

    final searchQuery = query.toLowerCase();
    final results = widget.products.where((product) {
      return product.name.toLowerCase().contains(searchQuery) ||
          product.sku.toLowerCase().contains(searchQuery);
    }).toList();

    _searchResults[index]!.clear();
    _searchResults[index]!.addAll(results.take(5));
    setState(() {});
  }

  void _onProductSelected(int index, Product product) {
    _selectedProducts[index] = product;
    _controllers[index]!.text = product.name;
    _searchResults[index]!.clear();
    _focusNodes[index]!.unfocus();

    if (index == _productRows.length - 1) {
      _addNewRow();
    } else {
      _focusNodes[index + 1]?.requestFocus();
    }
    setState(() {});
  }

  void _onQuantityChanged(int index, String value) {
    _productRows[index].quantity = int.tryParse(value) ?? 1;
    setState(() {});
  }

  void _onPriceChanged(int index, String value) {
    final product = _selectedProducts[index];
    if (product != null) {
      _productRows[index].customPrice = double.tryParse(value);
      setState(() {});
    }
  }

  void _addNewRow() {
    final newIndex = _productRows.length;
    _productRows.add(POSProductRow());
    _focusNodes[newIndex] = FocusNode();
    _controllers[newIndex] = TextEditingController();
    _searchResults[newIndex] = [];
    _selectedProducts[newIndex] = null;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newIndex]!.requestFocus();
    });
  }

  void _removeRow(int index) {
    if (_productRows.length > 1) {
      _productRows.removeAt(index);
      _focusNodes.remove(index);
      _controllers.remove(index);
      _searchResults.remove(index);
      _selectedProducts.remove(index);

      final newFocusNodes = <int, FocusNode>{};
      final newControllers = <int, TextEditingController>{};
      final newSearchResults = <int, List<Product>>{};
      final newSelectedProducts = <int, Product?>{};

      for (int i = 0; i < _productRows.length; i++) {
        newFocusNodes[i] = _focusNodes[i] ?? FocusNode();
        newControllers[i] = _controllers[i] ?? TextEditingController();
        newSearchResults[i] = _searchResults[i] ?? [];
        newSelectedProducts[i] = _selectedProducts[i];
      }

      setState(() {
        _focusNodes.clear();
        _focusNodes.addAll(newFocusNodes);
        _controllers.clear();
        _controllers.addAll(newControllers);
        _searchResults.clear();
        _searchResults.addAll(newSearchResults);
        _selectedProducts.clear();
        _selectedProducts.addAll(newSelectedProducts);
      });
    }
  }

  double _calculateLineTotal(int index) {
    final product = _selectedProducts[index];
    final row = _productRows[index];
    if (product == null) return 0.0;

    final price = row.customPrice ?? product.price;
    return price * row.quantity;
  }

  double _calculateGrandTotal() {
    double total = 0.0;
    for (int i = 0; i < _productRows.length; i++) {
      total += _calculateLineTotal(i);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Product Entry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    color: Colors.grey[50],
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'PRODUCT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'QTY',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'PRICE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        SizedBox(width: 40),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _productRows.length,
                    itemBuilder: (context, index) {
                      return _buildProductRow(index);
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.add, size: 18),
                      label: Text('Add Another Product'),
                      onPressed: _addNewRow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRAND TOTAL',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_calculateGrandTotal().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.shopping_cart_checkout),
                  label: Text('Add to Cart'),
                  onPressed: _addAllToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  Widget _buildProductRow(int index) {
    final product = _selectedProducts[index];
    final row = _productRows[index];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  decoration: InputDecoration(
                    hintText: 'Search product...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: _controllers[index]!.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _controllers[index]!.clear();
                        _searchResults[index]!.clear();
                        _selectedProducts[index] = null;
                        setState(() {});
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) => _onProductSearchChanged(index, value),
                ),
                if (_searchResults[index]!.isNotEmpty &&
                    _focusNodes[index]!.hasFocus)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(blurRadius: 4, color: Colors.black12),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _searchResults[index]!.map((product) {
                        return ListTile(
                          dense: true,
                          leading: product.imageUrls.isNotEmpty
                              ? CircleAvatar(
                            backgroundImage: NetworkImage(
                              product.imageUrls.first,
                            ),
                            radius: 16,
                          )
                              : CircleAvatar(
                            radius: 16,
                            child: Image.asset(
                              'assets/product-placeholder.jpeg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            'SKU: ${product.sku} | \$${product.price}',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () => _onProductSelected(index, product),
                        );
                      }).toList(),
                    ),
                  ),
                if (product != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SKU: ${product.sku}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (product.inStock)
                          Text(
                            'In Stock',
                            style: TextStyle(fontSize: 11, color: Colors.green),
                          )
                        else
                          Text(
                            'Out of Stock',
                            style: TextStyle(fontSize: 11, color: Colors.red),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Qty',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _onQuantityChanged(index, value),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Price',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => _onPriceChanged(index, value),
                ),
                if (product != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Original: \$${product.price}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '\$${_calculateLineTotal(index).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _removeRow(index),
            tooltip: 'Remove Row',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNodes.forEach((_, node) => node.dispose());
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}

class POSProductRow {
  int quantity;
  double? customPrice;

  POSProductRow({this.quantity = 1, this.customPrice});
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: ProductImage(
                  imageUrl: product.imageUrl,
                  imageUrls: product.imageUrls,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (product.sku.isNotEmpty)
                Text(
                  product.sku,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (product.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: product.categories.take(2).map((category) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                  Text(
                    'Stock: ${product.stockQuantity}',
                    style: TextStyle(
                      fontSize: 11,
                      color: product.inStock
                          ? Colors.green[600]
                          : Colors.red[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: product.inStock && product.stockQuantity > 0
                    ? ElevatedButton(
                  onPressed: onAddToCart,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: ThemeUtils.primary(context),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_shopping_cart,
                        size: 16,
                        color: ThemeUtils.textOnPrimary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ADD',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeUtils.textOnPrimary(context),
                        ),
                      ),
                    ],
                  ),
                )
                    : OutlinedButton(
                  onPressed: null, // Disabled button
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: Colors.grey[400]!),
                    backgroundColor: Colors.grey[50],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'OUT OF STOCK',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class RecentProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const RecentProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = !product.inStock || product.stockQuantity == 0;

    return Card(
      elevation: isOutOfStock ? 1 : 2,
      color: isOutOfStock ? Colors.grey[50] : Colors.white,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              SizedBox(
                height: 60,
                width: 60,
                child: Stack(
                  children: [
                    ProductImage(
                      imageUrl: product.imageUrl,
                      imageUrls: product.imageUrls,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    if (isOutOfStock)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isOutOfStock ? Colors.grey[600] : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(
                '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOutOfStock ? Colors.grey[500] : Colors.green[700],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOutOfStock ? Colors.grey[100] : Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isOutOfStock ? Colors.grey[300]! : Colors.green[100]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOutOfStock ? Icons.inventory_2_outlined : Icons.check_circle_outline,
                      size: 10,
                      color: isOutOfStock ? Colors.grey[500] : Colors.green[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isOutOfStock ? 'Out of Stock' : 'In Stock',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isOutOfStock ? Colors.grey[600] : Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class ProductDetailBottomSheet extends StatefulWidget {
  final Product product;
  final VoidCallback onAddToCart;

  const ProductDetailBottomSheet({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  _ProductDetailBottomSheetState createState() =>
      _ProductDetailBottomSheetState();
}

class _ProductDetailBottomSheetState extends State<ProductDetailBottomSheet> {
  int _quantity = 1;

  void _incrementQuantity() {
    if (_quantity < widget.product.stockQuantity) {
      setState(() => _quantity++);
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  void _addToCartWithQuantity() {
    for (int i = 0; i < _quantity; i++) {
      widget.onAddToCart();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = !widget.product.inStock || widget.product.stockQuantity == 0;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    children: [
                      ProductImage(
                        imageUrl: widget.product.imageUrl,
                        imageUrls: widget.product.imageUrls,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      if (isOutOfStock)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.block,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.product.sku.isNotEmpty)
                        Text(
                          'SKU: ${widget.product.sku}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Price: ${Constants.CURRENCY_NAME}${widget.product.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isOutOfStock ? Colors.grey[600] : Colors.green[700],
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isOutOfStock ? Icons.error : Icons.check_circle,
                  color: isOutOfStock ? Colors.red : Colors.green,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  isOutOfStock
                      ? 'Out of stock'
                      : '${widget.product.stockQuantity} in stock',
                  style: TextStyle(
                    color: isOutOfStock ? Colors.red[600] : Colors.green[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (widget.product.description != null &&
                widget.product.description!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.product.description!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            if (!isOutOfStock) ...[
              Text('Quantity:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove, size: 20),
                          onPressed: _decrementQuantity,
                          padding: EdgeInsets.zero,
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            _quantity.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, size: 20),
                          onPressed: _incrementQuantity,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Total: ${Constants.CURRENCY_NAME}${(widget.product.price * _quantity).toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 24),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: isOutOfStock
                      ? ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Out of Stock'),
                      ],
                    ),
                  )
                      : ElevatedButton(
                    onPressed: _addToCartWithQuantity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart, size: 20),
                        SizedBox(width: 8),
                        Text('Add $_quantity to Cart'),
                      ],
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
}
class Attribute {
  final int id;
  final String name;
  final String slug;
  final List<String> options;
  final bool visible;
  final bool variation;

  Attribute({
    required this.id,
    required this.name,
    required this.slug,
    required this.options,
    required this.visible,
    required this.variation,
  });

  factory Attribute.fromFirestore(Map<String, dynamic> data, int id) {
    final List<String> parsedOptions = [];
    if (data['options'] is List) {
      for (var option in data['options']) {
        if (option != null) {
          parsedOptions.add(option.toString());
        }
      }
    }

    return Attribute(
      id: id,
      name: data['name']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      options: parsedOptions,
      visible: data['visible'] ?? false,
      variation: data['variation'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'options': options,
      'visible': visible,
      'variation': variation,
    };
  }
}

