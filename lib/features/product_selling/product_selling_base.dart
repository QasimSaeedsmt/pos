
import 'package:flutter/material.dart';
class Product {
  final String id;
  final String name;
  final String sku;
  final double price;
  final double? regularPrice;
  final double? salePrice;
  final String? imageUrl;
  final List<String> imageUrls;
  final int stockQuantity;
  final bool inStock;
  final String stockStatus;
  final String? description;
  final String? shortDescription;
  final List<Category> categories;
  final List<Attribute> attributes;
  final Map<String, dynamic> metaData;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final bool purchasable;
  final String? type;
  final String? status;
  final bool featured;
  final String? permalink;
  final double? averageRating;
  final int? ratingCount;
  final String? parentId;
  final List<String> variations;
  final String? weight;
  final String? dimensions;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    this.regularPrice,
    this.salePrice,
    this.imageUrl,
    this.imageUrls = const [],
    required this.stockQuantity,
    required this.inStock,
    required this.stockStatus,
    this.description,
    this.shortDescription,
    this.categories = const [],
    this.attributes = const [],
    this.metaData = const {},
    this.dateCreated,
    this.dateModified,
    this.purchasable = true,
    this.type,
    this.status,
    this.featured = false,
    this.permalink,
    this.averageRating,
    this.ratingCount,
    this.parentId,
    this.variations = const [],
    this.weight,
    this.dimensions,
  });

  List<String> get categoryNames => categories.map((cat) => cat.name).toList();

  bool hasCategory(String categoryId) {
    return categories.any((cat) => cat.id == categoryId);
  }

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    double? price,
    double? regularPrice,
    double? salePrice,
    String? imageUrl,
    List<String>? imageUrls,
    int? stockQuantity,
    bool? inStock,
    String? stockStatus,
    String? description,
    String? shortDescription,
    List<Category>? categories,
    List<Attribute>? attributes,
    Map<String, dynamic>? metaData,
    DateTime? dateCreated,
    DateTime? dateModified,
    bool? purchasable,
    String? type,
    String? status,
    bool? featured,
    String? permalink,
    double? averageRating,
    int? ratingCount,
    String? parentId,
    List<String>? variations,
    String? weight,
    String? dimensions,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      regularPrice: regularPrice ?? this.regularPrice,
      salePrice: salePrice ?? this.salePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      inStock: inStock ?? this.inStock,
      stockStatus: stockStatus ?? this.stockStatus,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      categories: categories ?? this.categories,
      attributes: attributes ?? this.attributes,
      metaData: metaData ?? this.metaData,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      purchasable: purchasable ?? this.purchasable,
      type: type ?? this.type,
      status: status ?? this.status,
      featured: featured ?? this.featured,
      permalink: permalink ?? this.permalink,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      parentId: parentId ?? this.parentId,
      variations: variations ?? this.variations,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
    );
  }

  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    final List<Category> parsedCategories = [];
    if (data['categories'] != null && data['categories'] is List) {
      for (var categoryData in data['categories']) {
        if (categoryData is Map<String, dynamic>) {
          parsedCategories.add(
            Category.fromFirestore(
              categoryData,
              categoryData['id']?.toString() ?? '',
            ),
          );
        }
      }
    }

    final List<Attribute> parsedAttributes = [];
    if (data['attributes'] != null && data['attributes'] is List) {
      for (var attributeData in data['attributes']) {
        if (attributeData is Map<String, dynamic>) {
          parsedAttributes.add(Attribute.fromFirestore(attributeData, 0));
        }
      }
    }

    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    final List<String> parsedImageUrls = [];
    String? primaryImageUrl;

    if (data['imageUrls'] != null && data['imageUrls'] is List) {
      for (var url in data['imageUrls']) {
        if (url != null) {
          parsedImageUrls.add(url.toString());
        }
      }
    }

    if (parsedImageUrls.isNotEmpty) {
      primaryImageUrl = parsedImageUrls.first;
    } else {
      primaryImageUrl = data['imageUrl']?.toString();
    }

    final productId = id.isNotEmpty ? id : data['id']?.toString() ?? '';

    return Product(
      id: productId,
      name: data['name']?.toString() ?? 'Unnamed Product',
      sku: data['sku']?.toString() ?? '',
      price: _parseDouble(data['price']) ?? 0.0,
      regularPrice: _parseDouble(data['regularPrice']),
      salePrice: _parseDouble(data['salePrice']),
      imageUrl: primaryImageUrl,
      imageUrls: parsedImageUrls,
      stockQuantity: _parseInt(data['stockQuantity']) ?? 0,
      inStock: data['inStock'] ?? (data['stockStatus'] == 'instock'),
      stockStatus: data['stockStatus']?.toString() ?? 'instock',
      description: data['description']?.toString(),
      shortDescription: data['shortDescription']?.toString(),
      categories: parsedCategories,
      attributes: parsedAttributes,
      metaData: data['metaData'] is Map
          ? Map<String, dynamic>.from(data['metaData'])
          : {},
      dateCreated: parseDate(data['dateCreated']),
      dateModified: parseDate(data['dateModified']),
      purchasable: data['purchasable'] ?? true,
      type: data['type']?.toString(),
      status: data['status']?.toString() ?? 'publish',
      featured: data['featured'] ?? false,
      permalink: data['permalink']?.toString(),
      averageRating: _parseDouble(data['averageRating']),
      ratingCount: _parseInt(data['ratingCount']),
      parentId: data['parentId']?.toString(),
      variations: data['variations'] is List
          ? List<String>.from(data['variations'])
          : [],
      weight: data['weight']?.toString(),
      dimensions: data['dimensions']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'price': price,
      'regularPrice': regularPrice,
      'salePrice': salePrice,
      'imageUrl': imageUrl,
      'stockQuantity': stockQuantity,
      'inStock': inStock,
      'stockStatus': stockStatus,
      'description': description,
      'shortDescription': shortDescription,
      'categories': categories.map((cat) => cat.toFirestore()).toList(),
      'attributes': attributes.map((attr) => attr.toFirestore()).toList(),
      'metaData': metaData,
      'dateCreated': dateCreated?.toIso8601String(),
      'dateModified': dateModified?.toIso8601String(),
      'purchasable': purchasable,
      'type': type,
      'status': status ?? 'publish',
      'featured': featured,
      'permalink': permalink,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'parentId': parentId,
      'variations': variations,
      'weight': weight,
      'dimensions': dimensions,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
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
      // For web, use screen width to determine desktop
      final mediaQuery = MediaQuery.of(context);
      return mediaQuery.size.width > 768;
    }
    // For mobile apps, check platform
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _setupCartListener();
    // Auto-set POS mode for desktop on init
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
    setState(() {
      _isLoading = true;
      _searchError = '';
    });
    try {
      final products = await _posService.fetchProducts(
        limit: 100,
        inStockOnly: _inStockOnly,
      );
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
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      print('Failed to load categories: $e');
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
      print('Failed to load recent products: $e');
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
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _posService.searchProducts(query);
        setState(() {
          _filteredProducts.clear();
          _filteredProducts.addAll(results);
        });
      } catch (e) {
        setState(() {
          _searchError = 'Search failed: $e';
        });
      }
    });
  }

  void _applyFilters() {
    List<Product> filtered = List.from(_products);
    if (_selectedCategoryId != 'all') {
      filtered = filtered.where((product) {
        return product.categories.any(
              (category) => category.id == _selectedCategoryId,
        );
      }).toList();
    }
    if (_inStockOnly) {
      filtered = filtered.where((product) => product.inStock).toList();
    }
    setState(() {
      _filteredProducts.clear();
      _filteredProducts.addAll(filtered);
    });
  }

  Future<void> _addToCart(Product product) async {
    try {
      await widget.cartManager.addToCart(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No product found with barcode: $barcode'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterBottomSheet(
        categories: _categories,
        selectedCategoryId: _selectedCategoryId,
        inStockOnly: _inStockOnly,
        onFiltersChanged: (categoryId, inStockOnly) {
          setState(() {
            _selectedCategoryId = categoryId;
            _inStockOnly = inStockOnly;
          });
          _applyFilters();
        },
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
    final displayProducts = _isSearching
        ? _filteredProducts
        : _filteredProducts;
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
        // Left sidebar - Product search and filters
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
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.filter_list, size: 18),
                            label: Text('Filters'),
                            onPressed: _showFilters,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
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
        // Main content area
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

    actions.addAll([
      Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CartScreen(cartManager: widget.cartManager),
                ),
              );
            },
          ),
          if (_cartItemCount > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  '$_cartItemCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      IconButton(
        icon: Icon(Icons.filter_list),
        onPressed: _showFilters,
        tooltip: 'Filters',
      ),
    ]);

    if (!_isDesktop) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Sell Products'),
        actions: _buildAppBarActions(),
      ),
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
          // Use custom price if provided, otherwise use product's original price
          final effectivePrice = row.customPrice ?? product.price;

          // Create product with custom price using copyWith
          final productToAdd = product.copyWith(price: effectivePrice);

          for (int j = 0; j < row.quantity; j++) {
            await widget.cartManager.addToCart(productToAdd);
          }
          addedCount += row.quantity;
        } catch (e) {
          errors.add('${product.name}: $e');
          print('Error adding product to cart: $e');
        }
      }
    }

    // Show results
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
        // Show detailed errors in a dialog
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
                        .toList(),
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

    final results = widget.products.where((product) {
      return product.name.toLowerCase().contains(query.toLowerCase()) ||
          product.sku.toLowerCase().contains(query.toLowerCase());
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
                            child: Icon(Icons.inventory_2, size: 16),
                            radius: 16,
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

// Product Card Widget
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
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: double.infinity,
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
                child: product.imageUrl == null
                    ? Center(
                  child: Icon(
                    Icons.shopping_bag,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                )
                    : null,
              ),
              SizedBox(height: 8),
              Text(
                product.name,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              if (product.sku.isNotEmpty)
                Text(
                  product.sku,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (product.categories.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: product.categories.take(2).map((category) {
                      return Container(
                        padding: EdgeInsets.symmetric(
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
              Spacer(),
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
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: product.inStock ? onAddToCart : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: product.inStock
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_shopping_cart, size: 16),
                      SizedBox(width: 4),
                      Text('ADD', style: TextStyle(fontSize: 12)),
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

// Recent Product Card (Horizontal List)
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
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              // Product Image
              Container(
                height: 60,
                width: 60,
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
                child: product.imageUrl == null
                    ? Center(
                  child: Icon(
                    Icons.shopping_bag,
                    size: 24,
                    color: Colors.grey[400],
                  ),
                )
                    : null,
              ),
              SizedBox(height: 4),

              // Product Name
              Text(
                product.name,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Spacer(),

              // Price
              Text(
                '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),

              // Stock Status
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: product.inStock ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.inStock ? 'In Stock' : 'Out of Stock',
                  style: TextStyle(
                    fontSize: 10,
                    color: product.inStock
                        ? Colors.green[700]
                        : Colors.red[700],
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

// Product Detail Bottom Sheet
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
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  image: widget.product.imageUrl != null
                      ? DecorationImage(
                    image: NetworkImage(widget.product.imageUrl!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: widget.product.imageUrl == null
                    ? Center(
                  child: Icon(Icons.shopping_bag, color: Colors.grey),
                )
                    : null,
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

          // Price
          Text(
            'Price: ${Constants.CURRENCY_NAME}${widget.product.price.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          SizedBox(height: 8),

          // Stock Information
          Row(
            children: [
              Icon(
                widget.product.inStock ? Icons.check_circle : Icons.error,
                color: widget.product.inStock ? Colors.green : Colors.red,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                widget.product.inStock
                    ? '${widget.product.stockQuantity} in stock'
                    : 'Out of stock',
                style: TextStyle(
                  color: widget.product.inStock
                      ? Colors.green[600]
                      : Colors.red[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Description
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

          // Quantity Selector
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

          // Action Buttons
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
                child: ElevatedButton(
                  onPressed: widget.product.inStock
                      ? _addToCartWithQuantity
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
    );
  }
}

// Filter Bottom Sheet
class FilterBottomSheet extends StatefulWidget {
  final List<Category> categories;
  final String selectedCategoryId;
  final bool inStockOnly;
  final Function(String, bool) onFiltersChanged;

  const FilterBottomSheet({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.inStockOnly,
    required this.onFiltersChanged,
  });

  @override
  _FilterBottomSheetState createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _selectedCategoryId;
  late bool _inStockOnly;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.selectedCategoryId;
    _inStockOnly = widget.inStockOnly;
  }

  void _applyFilters() {
    widget.onFiltersChanged(_selectedCategoryId, _inStockOnly);
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _selectedCategoryId = 'all';
      _inStockOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: _resetFilters, child: Text('Reset')),
            ],
          ),
          SizedBox(height: 16),
          Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('All Categories'),
                selected: _selectedCategoryId == 'all',
                onSelected: (selected) {
                  setState(() => _selectedCategoryId = 'all');
                },
              ),
              ...widget.categories.map((category) {
                return FilterChip(
                  label: Text(category.name),
                  selected: _selectedCategoryId == category.id,
                  onSelected: (selected) {
                    setState(() => _selectedCategoryId = category.id);
                  },
                );
              }),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _inStockOnly,
                onChanged: (value) {
                  setState(() => _inStockOnly = value ?? false);
                },
              ),
              Text('Show only in-stock products'),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _applyFilters,
              child: Text('APPLY FILTERS'),
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}
