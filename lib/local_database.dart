// class TenantProductsScreen extends StatefulWidget {
//   final EnhancedCartManager cartManager;
//
//   const TenantProductsScreen({Key? key, required this.cartManager}) : super(key: key);
//
//   @override
//   _TenantProductsScreenState createState() => _TenantProductsScreenState();
// }
//
// class _TenantProductsScreenState extends State<TenantProductsScreen> with SingleTickerProviderStateMixin {
//   final EnhancedPOSService _posService = EnhancedPOSService();
//   final List<Product> _products = [];
//   final List<Product> _filteredProducts = [];
//   final List<Product> _searchResults = [];
//   bool _isLoading = false;
//   bool _isInitialLoading = true;
//   bool _hasMore = true;
//   String? _lastDocumentId;
//   final int _perPage = 24;
//   final ScrollController _scrollController = ScrollController();
//   String _errorMessage = '';
//   final TextEditingController _searchController = TextEditingController();
//   final FocusNode _searchFocusNode = FocusNode();
//   Timer? _searchDebounceTimer;
//   bool _isSearching = false;
//   bool _showSearchResults = false;
//   String _lastSearchQuery = '';
//   String? _searchError;
//   String _selectedSort = 'name_asc';
//   double _minPrice = 0;
//   double _maxPrice = 1000;
//   bool _inStockOnly = false;
//   bool _onSaleOnly = false;
//   List<String> _selectedCategories = [];
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   bool _isBarcodeScanning = false;
//
//   // Search optimization
//   final Map<String, List<int>> _searchIndex = {};
//   final List<String> _productNames = [];
//   final List<String> _productSKUs = [];
//   bool _isIndexBuilt = false;
//
//   // Filter state
//   bool _showFilters = false;
//   final Map<String, List<String>> _availableCategories = {};
//   final TextEditingController _minPriceController = TextEditingController();
//   final TextEditingController _maxPriceController = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
//     );
//
//     _minPriceController.text = _minPrice.toString();
//     _maxPriceController.text = _maxPrice.toString();
//
//     _loadProducts();
//     _scrollController.addListener(_scrollListener);
//     _animationController.forward();
//   }
//
//   void _scrollListener() {
//     if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 400 &&
//         !_isLoading &&
//         _hasMore &&
//         !_showSearchResults &&
//         !_isSearching) {
//       _loadProducts();
//     }
//   }
//
//   Future<void> _loadProducts() async {
//     if (_isLoading) return;
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });
//
//     try {
//       final newProducts = await _posService.fetchProducts(
//         limit: _perPage,
//         lastDocumentId: _lastDocumentId,
//         inStockOnly: _inStockOnly,
//         minPrice: _minPrice,
//         maxPrice: _maxPrice,
//       );
//
//       if (mounted) {
//         setState(() {
//           if (_lastDocumentId == null) {
//             _products.clear();
//           }
//           _products.addAll(newProducts);
//           _lastDocumentId = newProducts.isNotEmpty ? newProducts.last.id : null;
//           _hasMore = newProducts.length == _perPage;
//           _isInitialLoading = false;
//         });
//
//         // Build search index after first load
//         if (!_isIndexBuilt && _products.isNotEmpty) {
//           _buildSearchIndex();
//         }
//
//         // Extract categories
//         _extractCategories(newProducts);
//
//         _applyFilters();
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _errorMessage = _posService.isOnline ? e.toString() : 'Offline - Using local data';
//         });
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
//
//   void _buildSearchIndex() {
//     _searchIndex.clear();
//     _productNames.clear();
//     _productSKUs.clear();
//
//     for (int i = 0; i < _products.length; i++) {
//       final product = _products[i];
//
//       // Index product name
//       final name = product.name.toLowerCase();
//       _productNames.add(name);
//
//       // Create trigrams for fuzzy search
//       for (int j = 0; j <= name.length - 3; j++) {
//         final trigram = name.substring(j, j + 3);
//         if (!_searchIndex.containsKey(trigram)) {
//           _searchIndex[trigram] = [];
//         }
//         _searchIndex[trigram]!.add(i);
//       }
//
//       // Index SKU if available
//       if (product.sku.isNotEmpty) {
//         final sku = product.sku.toLowerCase();
//         _productSKUs.add(sku);
//         for (int j = 0; j <= sku.length - 3; j++) {
//           final trigram = sku.substring(j, j + 3);
//           if (!_searchIndex.containsKey(trigram)) {
//             _searchIndex[trigram] = [];
//           }
//           _searchIndex[trigram]!.add(i);
//         }
//       }
//     }
//
//     _isIndexBuilt = true;
//   }
//
//   void _extractCategories(List<Product> products) {
//     for (final product in products) {
//       for (final category in product.categories) {
//         if (!_availableCategories.containsKey(category.name)) {
//           _availableCategories[category.name] = [];
//         }
//       }
//     }
//   }
//
//   void _onSearchTextChanged(String query) {
//     _searchDebounceTimer?.cancel();
//
//     setState(() {
//       _searchError = null;
//     });
//
//     if (query.isEmpty) {
//       setState(() {
//         _showSearchResults = false;
//         _isSearching = false;
//         _searchResults.clear();
//         _searchError = null;
//       });
//       return;
//     }
//
//     if (query.length < 2) {
//       return;
//     }
//
//     setState(() {
//       _isSearching = true;
//       _searchError = null;
//     });
//
//     _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
//       _performSearch(query);
//     });
//   }
//
//   Future<void> _performSearch(String query) async {
//     if (query.isEmpty || query.length < 2) return;
//
//     try {
//       // First, try fast local search
//       final localResults = _performFastLocalSearch(query);
//
//       if (mounted) {
//         setState(() {
//           _searchResults.clear();
//           _searchResults.addAll(localResults);
//           _showSearchResults = true;
//           _isSearching = false;
//           _lastSearchQuery = query;
//           _searchError = null;
//         });
//       }
//
//       // Then try API search for more comprehensive results
//       if (_posService.isOnline) {
//         final apiResults = await _posService.searchProducts(query);
//
//         if (mounted && query == _lastSearchQuery) {
//           setState(() {
//             // Merge API results with local results, removing duplicates
//             final Set<String> existingIds = _searchResults.map((p) => p.id).toSet();
//             final newResults = apiResults.where((p) => !existingIds.contains(p.id)).toList();
//             _searchResults.addAll(newResults);
//             _searchError = null;
//           });
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _isSearching = false;
//           _searchError = 'Search unavailable. Showing local results only.';
//         });
//       }
//     }
//   }
//
//   List<Product> _performFastLocalSearch(String query) {
//     final lowerQuery = query.toLowerCase();
//
//     // Exact match search (highest priority)
//     final exactMatches = _products.where((product) {
//       return product.name.toLowerCase() == lowerQuery ||
//           product.sku.toLowerCase() == lowerQuery;
//     }).toList();
//
//     if (exactMatches.isNotEmpty) {
//       return exactMatches;
//     }
//
//     // Fast trigram-based search
//     final Set<int> candidateIndices = {};
//     final Set<String> usedTrigrams = {};
//
//     // Generate trigrams from query
//     for (int i = 0; i <= lowerQuery.length - 3; i++) {
//       final trigram = lowerQuery.substring(i, i + 3);
//       usedTrigrams.add(trigram);
//
//       if (_searchIndex.containsKey(trigram)) {
//         candidateIndices.addAll(_searchIndex[trigram]!);
//       }
//     }
//
//     // Score and rank results
//     final List<MapEntry<Product, int>> scoredResults = [];
//
//     for (final index in candidateIndices) {
//       if (index >= _products.length) continue;
//
//       final product = _products[index];
//       int score = 0;
//
//       // Check name match
//       final name = _productNames[index];
//       if (name.contains(lowerQuery)) {
//         score += 100;
//       }
//
//       // Check trigram overlap
//       int trigramMatches = 0;
//       for (final trigram in usedTrigrams) {
//         if (name.contains(trigram)) {
//           trigramMatches++;
//         }
//       }
//       score += (trigramMatches * 10);
//
//       // Check SKU match
//       if (index < _productSKUs.length) {
//         final sku = _productSKUs[index];
//         if (sku.contains(lowerQuery)) {
//           score += 50;
//         }
//       }
//
//       // Check category matches
//       for (final category in product.categories) {
//         if (category.name.toLowerCase().contains(lowerQuery)) {
//           score += 30;
//         }
//       }
//
//       if (score > 0) {
//         scoredResults.add(MapEntry(product, score));
//       }
//     }
//
//     // Sort by score and return
//     scoredResults.sort((a, b) => b.value.compareTo(a.value));
//     return scoredResults.map((entry) => entry.key).toList();
//   }
//
//   List<Product> _performLocalSearch(String query) {
//     final lowerQuery = query.toLowerCase();
//     return _products.where((product) {
//       return product.name.toLowerCase().contains(lowerQuery) ||
//           product.sku.toLowerCase().contains(lowerQuery) ||
//           product.categories.any((category) =>
//               category.name.toLowerCase().contains(lowerQuery));
//     }).toList();
//   }
//
//   void _clearSearch() {
//     _searchController.clear();
//     _searchFocusNode.unfocus();
//     setState(() {
//       _showSearchResults = false;
//       _isSearching = false;
//       _searchResults.clear();
//       _searchError = null;
//     });
//   }
//
//   void _applyFilters() {
//     if (_products.isEmpty) return;
//
//     List<Product> filtered = List.from(_products);
//
//     // Price filter
//     filtered = filtered.where((product) {
//       return product.price >= _minPrice && product.price <= _maxPrice;
//     }).toList();
//
//     // Stock filter
//     if (_inStockOnly) {
//       filtered = filtered.where((product) => product.inStock).toList();
//     }
//
//     // Sale filter
//     if (_onSaleOnly) {
//       filtered = filtered.where((product) => product.isOnSale).toList();
//     }
//
//     // Category filter
//     if (_selectedCategories.isNotEmpty) {
//       filtered = filtered.where((product) {
//         return product.categories.any((category) =>
//             _selectedCategories.contains(category.name));
//       }).toList();
//     }
//
//     setState(() {
//       _filteredProducts.clear();
//       _filteredProducts.addAll(filtered);
//       _sortProducts();
//     });
//   }
//
//   void _sortProducts() {
//     if (_filteredProducts.isEmpty) return;
//
//     switch (_selectedSort) {
//       case 'name_asc':
//         _filteredProducts.sort((a, b) => a.name.compareTo(b.name));
//         break;
//       case 'name_desc':
//         _filteredProducts.sort((a, b) => b.name.compareTo(a.name));
//         break;
//       case 'price_asc':
//         _filteredProducts.sort((a, b) => a.price.compareTo(b.price));
//         break;
//       case 'price_desc':
//         _filteredProducts.sort((a, b) => b.price.compareTo(a.price));
//         break;
//       case 'stock_high':
//         _filteredProducts.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
//         break;
//       case 'stock_low':
//         _filteredProducts.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
//         break;
//       case 'recent':
//         _filteredProducts.sort((a, b) {
//           final aDate = a.dateCreated ?? DateTime(1900);
//           final bDate = b.dateCreated ?? DateTime(1900);
//           return bDate.compareTo(aDate);
//         });
//         break;
//     }
//   }
//
//   void _showFilterDialog(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => _buildFilterSheet(context),
//     );
//   }
//
//   Widget _buildFilterSheet(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       height: MediaQuery.of(context).size.height * 0.8,
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'Filters & Sort',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               IconButton(
//                 icon: Icon(Icons.close),
//                 onPressed: () => Navigator.of(context).pop(),
//               ),
//             ],
//           ),
//           Divider(),
//           Expanded(
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Sort Section
//                   _buildSortSection(),
//                   SizedBox(height: 20),
//
//                   // Price Filter
//                   _buildPriceFilterSection(),
//                   SizedBox(height: 20),
//
//                   // Stock & Sale Filters
//                   _buildToggleFiltersSection(),
//                   SizedBox(height: 20),
//
//                   // Category Filter
//                   if (_availableCategories.isNotEmpty) ...[
//                     _buildCategoryFilterSection(),
//                     SizedBox(height: 20),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//           // Action Buttons
//           _buildFilterActions(context),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSortSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Sort By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: [
//             _buildSortChip('Name A-Z', 'name_asc'),
//             _buildSortChip('Name Z-A', 'name_desc'),
//             _buildSortChip('Price Low-High', 'price_asc'),
//             _buildSortChip('Price High-Low', 'price_desc'),
//             _buildSortChip('Stock High', 'stock_high'),
//             _buildSortChip('Stock Low', 'stock_low'),
//             _buildSortChip('Recent', 'recent'),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSortChip(String label, String value) {
//     return ChoiceChip(
//       label: Text(label),
//       selected: _selectedSort == value,
//       onSelected: (selected) {
//         setState(() {
//           _selectedSort = value;
//         });
//         _applyFilters();
//         Navigator.of(context).pop();
//       },
//     );
//   }
//
//   Widget _buildPriceFilterSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Price Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//         SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: TextField(
//                 controller: _minPriceController,
//                 decoration: InputDecoration(
//                   labelText: 'Min Price',
//                   border: OutlineInputBorder(),
//                   prefixText: '${Constants.CURRENCY_NAME}',
//                 ),
//                 keyboardType: TextInputType.numberWithOptions(decimal: true),
//                 onChanged: (value) {
//                   final newValue = double.tryParse(value) ?? _minPrice;
//                   if (newValue != _minPrice) {
//                     setState(() => _minPrice = newValue);
//                   }
//                 },
//               ),
//             ),
//             SizedBox(width: 16),
//             Expanded(
//               child: TextField(
//                 controller: _maxPriceController,
//                 decoration: InputDecoration(
//                   labelText: 'Max Price',
//                   border: OutlineInputBorder(),
//                   prefixText: '${Constants.CURRENCY_NAME}',
//                 ),
//                 keyboardType: TextInputType.numberWithOptions(decimal: true),
//                 onChanged: (value) {
//                   final newValue = double.tryParse(value) ?? _maxPrice;
//                   if (newValue != _maxPrice) {
//                     setState(() => _maxPrice = newValue);
//                   }
//                 },
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 12),
//         RangeSlider(
//           values: RangeValues(_minPrice, _maxPrice),
//           min: 0,
//           max: 1000,
//           divisions: 100,
//           labels: RangeLabels(
//             '${Constants.CURRENCY_NAME}${_minPrice.toStringAsFixed(0)}',
//             '${Constants.CURRENCY_NAME}${_maxPrice.toStringAsFixed(0)}',
//           ),
//           onChanged: (values) {
//             setState(() {
//               _minPrice = values.start.roundToDouble();
//               _maxPrice = values.end.roundToDouble();
//               _minPriceController.text = _minPrice.toString();
//               _maxPriceController.text = _maxPrice.toString();
//             });
//           },
//         ),
//       ],
//     );
//   }
//
//   Widget _buildToggleFiltersSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Availability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         CheckboxListTile(
//           title: Text('In Stock Only'),
//           value: _inStockOnly,
//           onChanged: (value) {
//             setState(() => _inStockOnly = value ?? false);
//           },
//         ),
//         CheckboxListTile(
//           title: Text('On Sale Only'),
//           value: _onSaleOnly,
//           onChanged: (value) {
//             setState(() => _onSaleOnly = value ?? false);
//           },
//         ),
//       ],
//     );
//   }
//
//   Widget _buildCategoryFilterSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//         SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: _availableCategories.keys.map((category) {
//             return FilterChip(
//               label: Text(category),
//               selected: _selectedCategories.contains(category),
//               onSelected: (selected) {
//                 setState(() {
//                   if (selected) {
//                     _selectedCategories.add(category);
//                   } else {
//                     _selectedCategories.remove(category);
//                   }
//                 });
//               },
//             );
//           }).toList(),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFilterActions(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(
//           child: OutlinedButton(
//             onPressed: () {
//               _resetFilters();
//               Navigator.of(context).pop();
//             },
//             child: Text('Reset All'),
//           ),
//         ),
//         SizedBox(width: 16),
//         Expanded(
//           child: ElevatedButton(
//             onPressed: () {
//               _applyFilters();
//               Navigator.of(context).pop();
//             },
//             child: Text('Apply Filters'),
//           ),
//         ),
//       ],
//     );
//   }
//
//   void _resetFilters() {
//     setState(() {
//       _selectedSort = 'name_asc';
//       _minPrice = 0;
//       _maxPrice = 1000;
//       _inStockOnly = false;
//       _onSaleOnly = false;
//       _selectedCategories.clear();
//       _minPriceController.text = _minPrice.toString();
//       _maxPriceController.text = _maxPrice.toString();
//     });
//     _applyFilters();
//   }
//
//   Future<void> _scanBarcode(BuildContext context) async {
//     final barcode = await UniversalScanningService.scanBarcode(context, purpose: 'search');
//     if (barcode != null && barcode.isNotEmpty) {
//       await _searchProductByBarcode(barcode);
//     }
//   }
//
//
//   Future<void> _searchProductByBarcode(String barcode) async {
//     if (barcode.isEmpty) return;
//
//     setState(() => _isLoading = true);
//
//     try {
//       final localResults = _products.where((product) =>
//       product.sku.toLowerCase() == barcode.toLowerCase()).toList();
//
//       if (localResults.isNotEmpty) {
//         widget.cartManager.addToCart(localResults.first);
//         _showSnackBar('${localResults.first.name} added to cart', Colors.green);
//         setState(() => _isLoading = false);
//         return;
//       }
//
//       final apiResults = await _posService.searchProductsBySKU(barcode);
//
//       if (apiResults.isNotEmpty) {
//         widget.cartManager.addToCart(apiResults.first);
//         _showSnackBar('${apiResults.first.name} added to cart', Colors.green);
//       } else {
//         _showSnackBar('Product not found for barcode: $barcode', Colors.orange);
//       }
//     } catch (e) {
//       _showSnackBar('Search error: $e', Colors.red);
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
//
//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   List<Product> get _displayProducts {
//     return _showSearchResults ? _searchResults : _filteredProducts;
//   }
//
//   Widget _buildProductItem(Product product, int index) {
//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: ProductCard(
//         key: ValueKey('${product.id}_$index'),
//         product: product,
//         onAddToCart: () {
//           try {
//             widget.cartManager.addToCart(product);
//             _showSnackBar('${product.name} added to cart', Colors.green);
//           } catch (e) {
//             _showSnackBar('Failed to add product to cart', Colors.red);
//           }
//         },
//       ),
//     );
//   }
//
//   Widget _buildLoadingIndicator() {
//     return Padding(
//       padding: EdgeInsets.all(24),
//       child: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircularProgressIndicator(strokeWidth: 3, color: Colors.blue),
//             SizedBox(height: 8),
//             Text('Loading more products...', style: TextStyle(color: Colors.grey)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
//           SizedBox(height: 16),
//           Text(
//             _showSearchResults
//                 ? 'No products found for "$_lastSearchQuery"'
//                 : 'No products available',
//             style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//           ),
//           SizedBox(height: 8),
//           if (_showSearchResults)
//             ElevatedButton(
//               onPressed: _clearSearch,
//               child: Text('Clear Search'),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAppBar(BuildContext context) {
//     final appTheme = AppTheme();
//
//     return Container(
//       margin: EdgeInsets.all(16),
//       padding: EdgeInsets.symmetric(horizontal: 4),
//       decoration: BoxDecoration(
//         color: Colors.white,        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
//
//         borderRadius: BorderRadius.circular(16),
//         border: appTheme.enableGradient
//             ? Border.all(
//
//           color: appTheme.primaryColorValue.withOpacity(0.3),
//           width: 1,
//         )
//             : null,
//       ),
//
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _searchController,
//               focusNode: _searchFocusNode,
//               decoration: InputDecoration(
//                 hintText: 'Search products...',
//                 prefixIcon: Icon(Icons.search),
//                 suffixIcon: _searchController.text.isNotEmpty
//                     ? IconButton(
//                   icon: _isSearching
//                       ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
//                       : Icon(Icons.clear),
//                   onPressed: _clearSearch,
//                 )
//                     : null,
//                 border: InputBorder.none,
//               ),
//               onChanged: _onSearchTextChanged,
//             ),
//           ),
//           SizedBox(width: 8),
//           // Updated scan button
//           IconButton(
//             icon: _isBarcodeScanning
//                 ? CircularProgressIndicator(strokeWidth: 2, color: Colors.green)
//                 : Icon(Icons.qr_code_scanner),
//             onPressed: () => _scanBarcode(context),
//             tooltip: 'Scan Barcode',
//           ),
//           SizedBox(width: 4),
//           IconButton(
//             icon: Icon(Icons.filter_list),
//             onPressed: () => _showFilterDialog(context),
//             tooltip: 'Filters',
//           ),
//         ],
//       ),
//     );
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade50,
//       body: Column(
//         children: [
//           _buildAppBar(context),
//           if (_showSearchResults && _searchError != null)
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               color: Colors.orange[50],
//               child: Row(
//                 children: [
//                   Icon(Icons.warning, size: 16, color: Colors.orange),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       _searchError!,
//                       style: TextStyle(fontSize: 12, color: Colors.orange[800]),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           Expanded(
//             child: _isInitialLoading && _products.isEmpty
//                 ? Center(child: CircularProgressIndicator())
//                 : _displayProducts.isEmpty
//                 ? _buildEmptyState()
//                 : GridView.builder(
//               controller: _scrollController,
//               padding: EdgeInsets.all(16),
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: _getCrossAxisCount(context),
//                 crossAxisSpacing: 16,
//                 mainAxisExtent: MediaQuery.of(context).size.width >= 1024 ? 210 : MediaQuery.of(context).size.width >= 600 ? 280 : 240,
//                 mainAxisSpacing: 16,
//                 childAspectRatio: 0.72,
//               ),
//               itemCount: _displayProducts.length + (_hasMore && !_showSearchResults ? 1 : 0),
//               itemBuilder: (context, index) {
//                 if (index == _displayProducts.length && !_showSearchResults) {
//                   return _buildLoadingIndicator();
//                 }
//                 return _buildProductItem(_displayProducts[index], index);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   int _getCrossAxisCount(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     if (width > 1200) return 5;
//     if (width > 900) return 4;
//     if (width > 600) return 3;
//     return 2;
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     _searchDebounceTimer?.cancel();
//     _searchController.dispose();
//     _searchFocusNode.dispose();
//     _scrollController.dispose();
//     _minPriceController.dispose();
//     _maxPriceController.dispose();
//     super.dispose();
//   }
// }
// // Product Card Widget
// class ProductCard extends StatelessWidget {
//   final Product product;
//   final VoidCallback onAddToCart;
//   final VoidCallback? onTap;
//
//   const ProductCard({
//     Key? key,
//     required this.product,
//     required this.onAddToCart,
//     this.onTap,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//
//       elevation: 2,
//       child: InkWell(
//         onTap: onTap,
//         child: Padding(
//           padding: EdgeInsets.all(12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Product Image
//               Container(
//                 height: 20,
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(8),
//                   image: product.imageUrl != null
//                       ? DecorationImage(
//                     image: NetworkImage(product.imageUrl!),
//                     fit: BoxFit.cover,
//                   )
//                       : null,
//                 ),
//                 child: product.imageUrl == null
//                     ? Icon(Icons.shopping_bag, size: 40, color: Colors.black)
//                     : null,
//               ),
//               SizedBox(height: 8),
//               Spacer(),
//
//               // Product Name
//               Text(
//                 product.name,
//                 style: TextStyle(fontWeight: FontWeight.bold),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//               SizedBox(height: 4),
//
//               // SKU
//               if (product.sku.isNotEmpty)
//                 Text(
//                   'SKU: ${product.sku}',
//                   style: TextStyle(fontSize: 12, color: Colors.grey),
//                 ),
//
//               SizedBox(height: 8),
//
//               // Price and Stock
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}',
//                     style:
//
//                     TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green[700],
//                     ),
//                   ),
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: product.inStock && product.stockQuantity>0 ? Colors.green[50] : Colors.red[50],
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text.rich(
//                       TextSpan(
//                         children: product.inStock && product.stockQuantity>0
//                             ? [
//                           TextSpan(
//                             text: '${product.stockQuantity} ',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 11,
//                               color: Colors.green[800],
//                             ),
//                           ),
//                           TextSpan(
//                             text: 'in Stock',
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: Colors.green,
//                             ),
//                           ),
//                         ]
//                             : [
//                           TextSpan(
//                             text: 'Out of Stock',
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: Colors.red,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 8),
//               product.stockQuantity>0?
//               // Add to Cart Button
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: product.inStock ? onAddToCart : null,
//                   style: ElevatedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(vertical: 8),
//                   ),
//                   child: Text('Add to Cart'),
//                 ),
//               ):SizedBox(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
