import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mpcm/core/overlay_manager.dart';
import 'package:mpcm/features/users/users_base.dart';
import 'package:mpcm/theme_utils.dart';
import '../../constants.dart';
import '../../core/models/app_order_model.dart';
import '../../core/models/cart_item_model.dart';
import '../../core/models/category_model.dart';
import '../../core/models/product_model.dart';
import '../../printing/bottom_sheet.dart';
import '../cartBase/cart_base.dart';
import '../credit/credit_sale_modal.dart';
import '../credit/credit_sale_model.dart';
import '../customerBase/customer_base.dart';
import '../invoiceBase/invoice_and_printing_base.dart';
import '../main_navigation/main_navigation_base.dart';
import '../product_selling/product_selling_base.dart';

class SmartProductGrid extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onAddToCart;
  final Function(Product) onProductTap;
  final bool showCategoryFilter;
  final bool showStockStatus;
  final bool showQuickActions;

  const SmartProductGrid({
    super.key,
    required this.products,
    required this.onAddToCart,
    required this.onProductTap,
    this.showCategoryFilter = true,
    this.showStockStatus = true,
    this.showQuickActions = true,
  });

  @override
  _SmartProductGridState createState() => _SmartProductGridState();
}

class _SmartProductGridState extends State<SmartProductGrid> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _expandedProducts = {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        final childAspectRatio = _getChildAspectRatio(constraints.maxWidth);

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: widget.products.length,
          itemBuilder: (context, index) {
            final product = widget.products[index];
            return SmartProductCard(
              product: product,
              onAddToCart: () => widget.onAddToCart(product),
              onTap: () => widget.onProductTap(product),
              isExpanded: _expandedProducts[product.id] ?? false,
              onToggleExpand: () => _toggleProductExpansion(product.id),
              showStockStatus: widget.showStockStatus,
              showQuickActions: widget.showQuickActions,
            );
          },
        );
      },
    );
  }

  int _getCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 2;
  }

  double _getChildAspectRatio(double width) {
    if (width > 1200) return 0.85;
    if (width > 800) return 0.8;
    if (width > 600) return 0.75;
    return 0.7;
  }

  void _toggleProductExpansion(String productId) {
    setState(() {
      _expandedProducts[productId] = !(_expandedProducts[productId] ?? false);
    });
  }
}

class SmartProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;
  final VoidCallback onTap;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final bool showStockStatus;
  final bool showQuickActions;

  const SmartProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.onTap,
    required this.isExpanded,
    required this.onToggleExpand,
    this.showStockStatus = true,
    this.showQuickActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Overlays
              _buildProductImage(context),

              // Product Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name and Expand Button
                      _buildProductHeader(),

                      SizedBox(height: 8),

                      // Product Details
                      _buildProductDetails(),

                      Spacer(),

                      // Price and Actions
                      _buildProductFooter(context),
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

  Widget _buildProductImage(BuildContext context) {
    return Stack(
      children: [
        // Main Product Image
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: ProductImage(
              imageUrl: product.imageUrl,
              imageUrls: product.imageUrls,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Stock Status Badge
        if (showStockStatus && !product.inStock)
          Positioned(
            top: 12,
            left: 12,
            child: _buildStockBadge(),
          ),

        // Quick Actions Overlay
        if (showQuickActions)
          Positioned(
            top: 12,
            right: 12,
            child: _buildQuickActions(),
          ),

        // Gradient Overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Out of Stock',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: Colors.grey[700],
            ),
            onPressed: onToggleExpand,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                  height: 1.2,
                ),
                maxLines: isExpanded ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (product.sku.isNotEmpty) ...[
                SizedBox(height: 2),
                Text(
                  product.sku,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetails() {
    return AnimatedCrossFade(
      duration: Duration(milliseconds: 300),
      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: SizedBox.shrink(),
      secondChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories
          if (product.categories.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: product.categories.take(2).map((category) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8),
          ],

          // Stock Information
          if (showStockStatus) ...[
            Row(
              children: [
                Icon(Icons.inventory_2, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  '${product.stockQuantity} in stock',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
          ],

          // Profit Margin (if available)
          if (product.purchasePrice != null) ...[
            Row(
              children: [
                Icon(Icons.trending_up, size: 12, color: _getProfitColor()),
                SizedBox(width: 4),
                Text(
                  '${product.profitMargin.toStringAsFixed(1)}% margin',
                  style: TextStyle(
                    fontSize: 11,
                    color: _getProfitColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price
        Text(
          '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.green[700],
          ),
        ),

        SizedBox(height: 12),

        // Add to Cart Button
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: product.inStock && product.stockQuantity > 0 ? onAddToCart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: product.inStock && product.stockQuantity > 0
                  ? ThemeUtils.primary(context)
                  : Colors.grey[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  product.inStock && product.stockQuantity > 0
                      ? Icons.add_shopping_cart
                      : Icons.inventory_2,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  product.inStock && product.stockQuantity > 0 ? 'ADD TO CART' : 'OUT OF STOCK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getProfitColor() {
    final margin = product.profitMargin;
    if (margin >= 50) return Colors.green;
    if (margin >= 20) return Colors.orange;
    return Colors.red;
  }
}

class SmartCategoryFilter extends StatefulWidget {
  final List<Category> categories;
  final String selectedCategoryId;
  final Function(String) onCategorySelected;
  final bool showAllOption;

  const SmartCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.showAllOption = true,
  });

  @override
  _SmartCategoryFilterState createState() => _SmartCategoryFilterState();
}

class _SmartCategoryFilterState extends State<SmartCategoryFilter> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (widget.showAllOption)
            _buildCategoryChip('All', 'all', Icons.all_inclusive),
          ...widget.categories.map((category) =>
              _buildCategoryChip(category.name, category.id, Icons.category)
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String name, String id, IconData icon) {
    final isSelected = widget.selectedCategoryId == id;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[700]),
            SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) => widget.onCategorySelected(id),
        backgroundColor: Colors.grey[100],
        selectedColor: ThemeUtils.primary(context),
        checkmarkColor: Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected ? ThemeUtils.primary(context) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
    );
  }
}

class SmartSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearchChanged;
  final Function() onScanPressed;
  final String hintText;
  final bool showScanButton;

  const SmartSearchBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.onScanPressed,
    this.hintText = 'Search products...',
    this.showScanButton = true,
  });

  @override
  _SmartSearchBarState createState() => _SmartSearchBarState();
}

class _SmartSearchBarState extends State<SmartSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _hasFocus ? ThemeUtils.primary(context) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.grey[500],
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              onChanged: widget.onSearchChanged,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
              onPressed: () {
                widget.controller.clear();
                widget.onSearchChanged('');
                _focusNode.unfocus();
              },
            ),
          ],
          if (widget.showScanButton) ...[
            Container(
              width: 1,
              height: 24,
              color: Colors.grey[300],
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.qr_code_scanner, size: 20, color: Colors.blue[600]),
              onPressed: widget.onScanPressed,
              tooltip: 'Scan Barcode',
            ),
          ],
        ],
      ),
    );
  }
}

class SmartEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final bool showButton;

  const SmartEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.buttonText = 'Try Again',
    required this.onButtonPressed,
    this.showButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (showButton) ...[
              SizedBox(height: 24),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeUtils.primary(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Enhanced Product Detail Bottom Sheet
class SmartProductDetailSheet extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;
  final bool showProfitInfo;

  const SmartProductDetailSheet({
    super.key,
    required this.product,
    required this.onAddToCart,
    this.showProfitInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Drag Handle
            Container(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Product Image Gallery
            _buildImageGallery(),

            // Product Details
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Header
                    _buildProductHeader(),

                    SizedBox(height: 16),

                    // Product Info Grid
                    _buildInfoGrid(),

                    SizedBox(height: 16),

                    // Description
                    if (product.description != null && product.description!.isNotEmpty)
                      _buildDescription(),

                    SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    final images = [product.imageUrl, ...product.imageUrls].where((url) => url != null && url.isNotEmpty).toList();

    return SizedBox(
      height: 200,
      child: PageView.builder(
        itemCount: images.isEmpty ? 1 : images.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[100],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ProductImage(
                imageUrl: images.isEmpty ? null : images[index],
                imageUrls: [],
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 4),
        if (product.sku.isNotEmpty)
          Text(
            'SKU: ${product.sku}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem('Price', '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}', Icons.attach_money),
          _buildInfoItem('Stock', '${product.stockQuantity}', Icons.inventory_2),
          if (showProfitInfo && product.purchasePrice != null)
            _buildInfoItem('Margin', '${product.profitMargin.toStringAsFixed(1)}%', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        Text(
          product.description!,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('CLOSE'),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: product.inStock && product.stockQuantity > 0 ? onAddToCart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeUtils.primary(context),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_shopping_cart, size: 20),
                SizedBox(width: 8),
                Text('ADD TO CART'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AllInOnePOSScreen extends StatefulWidget {
  final EnhancedCartManager cartManager;

  const AllInOnePOSScreen({super.key, required this.cartManager});

  @override
  _AllInOnePOSScreenState createState() => _AllInOnePOSScreenState();
}

class _AllInOnePOSScreenState extends State<AllInOnePOSScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  AppUser? currentUser;
  final TextEditingController _searchController = TextEditingController();
  final List<Product> _products = [];
  final List<Product> _filteredProducts = [];
  final List<Category> _categories = [];
  String _selectedCategoryId = 'all';
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchError = '';
  Timer? _searchDebounce;
  int _cartItemCount = 0;
  bool _inStockOnly = true;

  // Checkout state
  CustomerSelection _customerSelection = CustomerSelection(useDefault: true);
  String _selectedPaymentMethod = 'cash';
  double _additionalDiscount = 0.0;
  double _shippingAmount = 0.0;
  double _tipAmount = 0.0;
  bool _isProcessing = false;
  bool _isCreditSale = false;
  CreditSaleData? _creditSaleData;

  // UI State
  int _currentSection = 0; // 0: Selling, 1: Checkout, 2: Payment

  // Payment methods
  final List<String> _paymentMethods = [
    'cash',
    'easypaisa/bank transfer',
    'credit',
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _setupCartListener();
    _loadCurrentUser();
  }

  // ADD THIS METHOD - Simple user loading
  Future<void> _loadCurrentUser() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        // Get user from Firestore or create default
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            currentUser = AppUser.fromFirestore(userDoc);
          });
        } else {
          // Create default user if not found in Firestore
          setState(() {
            currentUser = AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? 'unknown@email.com',
              displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Cashier',
              phoneNumber: firebaseUser.phoneNumber,
              role: UserRole.cashier,
              tenantId: 'default_tenant',
              isActive: true,
              createdAt: DateTime.now(),
              createdBy: 'system',
              profile: {},
              permissions: [],
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
      // Create a basic user as fallback
      setState(() {
        currentUser = AppUser(
          uid: 'fallback_user',
          email: 'cashier@store.com',
          displayName: 'Cashier',
          role: UserRole.cashier,
          tenantId: 'default_tenant',
          isActive: true,
          createdAt: DateTime.now(),
          createdBy: 'system',
          profile: {},
          permissions: [],
        );
      });
    }
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

    // Initialize cart count
    if (mounted) {
      setState(() {
        _cartItemCount = widget.cartManager.items.length;
      });
    }
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
      if (mounted) {
        setState(() {
          _searchError = 'Failed to load products: $e';
          _isLoading = false;
        });
      }
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
  bool _hasProductCategory(Product product, String categoryId) {
    if (product.categories.isEmpty) {
      return false;
    }

    // Debug: Print all categories for this product
    debugPrint('Checking product "${product.name}" for category ID: $categoryId');
    debugPrint('Product categories:');
    for (final cat in product.categories) {
      debugPrint('  - "${cat.name}" (ID: "${cat.id}") [Length: ${cat.id.length}]');
    }

    // FIX: Compare by NAME if ID is empty, or by ID if available
    final hasCategory = product.categories.any((category) {
      // If category has a valid ID, use ID comparison
      if (category.id.isNotEmpty) {
        final matches = category.id == categoryId;
        if (matches) {
          debugPrint('  ✅ MATCH by ID: ${category.id} == $categoryId');
        }
        return matches;
      }
      // If category ID is empty, try to match by NAME
      else {
        // Find the category by name from available categories
        final matchingCategory = _categories.firstWhere(
              (availableCat) => availableCat.name == category.name,
          orElse: () => Category(id: '', name: '', slug: '', count: 0),
        );

        if (matchingCategory.id.isNotEmpty) {
          final matches = matchingCategory.id == categoryId;
          if (matches) {
            debugPrint('  ✅ MATCH by NAME: "${category.name}" -> ID: ${matchingCategory.id} == $categoryId');
          }
          return matches;
        }
      }

      return false;
    });

    debugPrint('  Result: $hasCategory');
    return hasCategory;
  }
  void _applyFilters() {
    List<Product> filtered = List.from(_products);

    // Apply category filter
    if (_selectedCategoryId != 'all') {
      debugPrint('=== CATEGORY FILTER DEBUG ===');
      debugPrint('Filtering for category ID: "$_selectedCategoryId"');

      filtered = filtered.where((product) {
        return _hasProductCategory(product, _selectedCategoryId);
      }).toList();

      debugPrint('Products after category filter: ${filtered.length}');
      debugPrint('=== END CATEGORY FILTER DEBUG ===');
    }

    // Apply stock filter
    if (_inStockOnly) {
      filtered = filtered.where((product) => product.inStock && product.stockQuantity > 0).toList();
    }

    // Apply search filter if active
    if (_isSearching && _searchController.text.isNotEmpty) {
      final searchQuery = _searchController.text.toLowerCase().trim();
      filtered = filtered.where((product) => _matchesSearchQuery(product, searchQuery)).toList();
    }

    setState(() {
      _filteredProducts.clear();
      _filteredProducts.addAll(filtered);
    });
  }
  bool _matchesSearchQuery(Product product, String query) {
    if (product.name.toLowerCase().contains(query)) return true;
    if (product.sku.toLowerCase().contains(query)) return true;
    if (product.description?.toLowerCase().contains(query) == true) return true;

    // Search in categories
    for (final category in product.categories) {
      if (category.name.toLowerCase().contains(query)) return true;
    }

    return false;
  }

  Future<void> _addToCart(Product product) async {
    try {
      // Check if product is still in stock
      if (!product.inStock || product.stockQuantity <= 0) {
        OverlayManager.showToast(
          context: context,
          message: 'Product is out of stock',
          backgroundColor: Colors.red,
        );
        return;
      }

      await widget.cartManager.addToCart(product);
      OverlayManager.showToast(
        context: context,
        message: '${product.name} added to cart',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      OverlayManager.showToast(
        context: context,
        message: e.toString(),
        backgroundColor: Colors.red,
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
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

  // Simple navigation between sections - no auto-switching
  void _navigateToSection(int section) {
    setState(() {
      _currentSection = section;
    });
  }

  // Checkout Methods
  Future<void> _selectCustomer() async {
    final result = await Navigator.push<CustomerSelection>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerSelectionScreen(
          posService: _posService,
          initialSelection: _customerSelection,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _customerSelection = result;
      });
    }
  }

  void _showAdditionalDiscountDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Additional Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current taxable amount: ${Constants.CURRENCY_NAME}${_taxableAmount.toStringAsFixed(2)}',
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          if (_additionalDiscount > 0)
            TextButton(
              onPressed: () {
                if (mounted) {
                  setState(() => _additionalDiscount = 0.0);
                }
                Navigator.pop(context);
                OverlayManager.showToast(
                  context: context,
                  message: 'Additional discount removed',
                );
              },
              child: Text(
                'Remove Discount',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final discount = double.tryParse(controller.text);
              if (discount != null && discount > 0) {
                if (mounted) {
                  setState(() => _additionalDiscount = discount);
                }
                Navigator.pop(context);
                OverlayManager.showToast(
                  context: context,
                  message: 'Additional discount applied',
                );
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  void _showCreditSaleModal() {
    if (!_customerSelection.hasCustomer) {
      OverlayManager.showToast(
        context: context,
        message: 'Please select a customer for credit sale',
        backgroundColor: Colors.orange,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreditSaleModal(
        selectedCustomer: _customerSelection.customer!,
        orderTotal: _finalTotal,
        onConfirm: (creditData) {
          if (mounted) {
            setState(() {
              _creditSaleData = creditData;
              _selectedPaymentMethod = 'credit';
              _isCreditSale = true;
            });
          }
          Navigator.pop(context);
          OverlayManager.showToast(
            context: context,
            message: 'Credit sale configured successfully',
            backgroundColor: Colors.green,
          );
        },
        onCancel: () {
          if (mounted) {
            setState(() {
              _isCreditSale = false;
              _creditSaleData = null;
              _selectedPaymentMethod = 'cash';
            });
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  // Total Calculations with null safety
  double get _subtotal => widget.cartManager.subtotal;
  double get _itemDiscounts => widget.cartManager.items.fold(
    0.0,
        (sum, item) => sum + (item.discountAmount ?? 0.0),
  );
  double get _cartDiscount => (widget.cartManager.cartDiscount ?? 0.0) +
      (_subtotal * (widget.cartManager.cartDiscountPercent ?? 0.0) / 100);
  double get _totalDiscount => _itemDiscounts + _cartDiscount + _additionalDiscount;
  double get _taxableAmount => (_subtotal - _totalDiscount).clamp(0.0, double.infinity);
  double get _taxAmount => _taxableAmount * (widget.cartManager.taxRate ?? 0.0) / 100;
  double get _finalTotal => _taxableAmount + _taxAmount + _shippingAmount + _tipAmount;

  // Process Order with enhanced error handling
  Future<void> _processOrder() async {
    if (widget.cartManager.items.isEmpty) {
      OverlayManager.showToast(
        context: context,
        message: 'Cart is empty',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Validate stock before processing
    for (final item in widget.cartManager.items) {
      final product = _products.firstWhere(
            (p) => p.id == item.product.id,
        orElse: () => item.product,
      );

      if (!product.inStock || product.stockQuantity < item.quantity) {
        OverlayManager.showToast(
          context: context,
          message: '${product.name} is out of stock or quantity unavailable',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final orderData = {
        'cartData': widget.cartManager.getCartDataForOrder(),
        'additionalDiscount': _additionalDiscount,
        'shippingAmount': _shippingAmount,
        'tipAmount': _tipAmount,
        'finalTotal': _finalTotal,
        'paymentMethod': _selectedPaymentMethod,
        'isCreditSale': _isCreditSale,
        'creditAmount': _creditSaleData?.creditAmount,
        'paidAmount': _creditSaleData?.paidAmount,
        'previousBalance': _creditSaleData?.previousBalance,
        'newBalance': _creditSaleData?.newBalance,
        // Include cart manager data for sync
        'cartManager': {
          'cartDiscount': widget.cartManager.cartDiscount,
          'cartDiscountPercent': widget.cartManager.cartDiscountPercent,
          'taxRate': widget.cartManager.taxRate,
        },
      };

      // Use offline-first approach (always saves locally first)
      final result = await _posService.createOrderWithEnhancedData(
        widget.cartManager.items,
        _customerSelection,
        additionalData: orderData,
        cartManager: widget.cartManager,
        creditSaleData: _isCreditSale ? _creditSaleData : null,
      );

      if (result.success) {
        // Update local product stock (already done in service, but update UI)
        _updateProductStockLocally(widget.cartManager.items);

        // Clear cart
        await widget.cartManager.clearCart();

        // Show success message - IMMEDIATELY after local save
        OverlayManager.showToast(
          context: context,
          message: _isCreditSale
              ? 'Credit sale processed successfully!'
              : 'Order processed successfully!',
          backgroundColor: Colors.green,
        );

        // Show invoice options (using local data)
        if (result.pendingOrderId != null) {
          _showOfflineInvoiceOptions(result.pendingOrderId!);
        }

        // Reset UI
        _resetPOSAfterSuccessfulSale();

        // Background sync will happen automatically via _startBackgroundSyncForOrder

      } else {
        OverlayManager.showToast(
          context: context,
          message: 'Order failed: ${result.error}',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      OverlayManager.showToast(
        context: context,
        message: 'Order failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  Future<void> _refreshProductsAfterSale() async {
    try {
      final updatedProducts = await _posService.fetchProducts(
        limit: 100,
        inStockOnly: false,
      );

      if (mounted) {
        setState(() {
          _products.clear();
          _products.addAll(updatedProducts);
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh products after sale: $e');
      // Even if refresh fails, continue with reset
    }
  }

  void _updateProductStockLocally(List<CartItem> soldItems) {
    for (final cartItem in soldItems) {
      final productId = cartItem.product.id;
      final soldQuantity = cartItem.quantity;

      final productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex != -1) {
        final currentProduct = _products[productIndex];
        final newStockQuantity = currentProduct.stockQuantity - soldQuantity;

        final updatedProduct = currentProduct.copyWith(
          stockQuantity: newStockQuantity,
          inStock: newStockQuantity > 0,
        );

        setState(() {
          _products[productIndex] = updatedProduct;
        });
      }
    }
    _applyFilters();
  }

  void _showEnhancedInvoiceOptions(AppOrder order, Map<String, dynamic> enhancedData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceOptionsBottomSheetWithOptions(
        order: order,
        customer: _customerSelection.hasCustomer ? _customerSelection.customer : null,
        enhancedData: enhancedData,
        creditSaleData: _isCreditSale ? _creditSaleData : null,
        currentUser: currentUser,
      ),
    ).then((_) {
      _resetPOSAfterSuccessfulSale();
    });
  }

  void _showOfflineInvoiceOptions(int pendingOrderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => OfflineInvoiceBottomSheet(
        pendingOrderId: pendingOrderId,
        customer: _customerSelection.hasCustomer ? _customerSelection.customer : null,
        finalTotal: _finalTotal,
        paymentMethod: _selectedPaymentMethod,
        businessInfo: {},
        invoiceSettings: {},
      ),
    ).then((_) {
      _resetPOSAfterSuccessfulSale();
    });
  }

  void _resetPOS() {
    _resetPOSAfterSuccessfulSale();
  }

  // NEW METHOD: Reset POS after successful sale
  void _resetPOSAfterSuccessfulSale() {
    if (!mounted) return;

    // Reset all state variables
    setState(() {
      // Reset UI state
      _currentSection = 0;

      // Reset search and filters
      _searchController.clear();
      _selectedCategoryId = 'all';
      _inStockOnly = false;
      _isSearching = false;
      _searchError = '';

      // Reset checkout state
      _additionalDiscount = 0.0;
      _shippingAmount = 0.0;
      _tipAmount = 0.0;
      _selectedPaymentMethod = 'cash';
      _customerSelection = CustomerSelection(useDefault: true);
      _isCreditSale = false;
      _creditSaleData = null;

      // Reset processing state
      _isProcessing = false;
    });

    // Clear the cart
    widget.cartManager.clearCart();

    // Refresh products to get updated stock
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProductsAfterSale();

      // Show success message
      OverlayManager.showToast(
        context: context,
        message: 'Sale completed successfully! \nReady for next customer.',
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      );
    });
  }

  // UI Sections - Fixed and stable
  Widget _buildSellingSection() {
    return Column(
      children: [
        // Search Bar
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
              _buildStockFilterToggle(),
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

        // Categories
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip('All', 'all'),
              ..._categories.map((category) => _buildCategoryChip(category.name, category.id)),
            ],
          ),
        ),

        // Products Grid
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProducts,
            child: _buildProductGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildStockFilterToggle() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text('In Stock Only'),
            selected: _inStockOnly,
            onSelected: (selected) {
              setState(() {
                _inStockOnly = selected;
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String name, String id) {
    final isSelected = _selectedCategoryId == id;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategoryId = id;
            _applyFilters();
          });
        },
        selectedColor: ThemeUtils.primary(context),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
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
            ElevatedButton(
                onPressed: _loadProducts,
                child: Text('Retry')
            ),
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
            if (_inStockOnly)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Try turning off "In Stock Only" filter',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (context, index) {
        final product = displayProducts[index];
        return QuickProductCard(
          product: product,
          onAddToCart: () => _addToCart(product),
        );
      },
    );
  }

  Widget _buildCheckoutSection() {
    return Column(
      children: [
        // Customer Section
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Information',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                        onPressed: _selectCustomer,
                        child: Text('Change')
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (_customerSelection.hasCustomer && _customerSelection.customer != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerSelection.customer!.displayName,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      if (_customerSelection.customer!.email.isNotEmpty)
                        Text(_customerSelection.customer!.email),
                      if (_customerSelection.customer!.phone.isNotEmpty)
                        Text(_customerSelection.customer!.phone),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Walk-in Customer',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        // Cart Items
        Expanded(
          child: widget.cartManager.items.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'Cart is empty',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _navigateToSection(0),
                  child: Text('Continue Shopping'),
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: widget.cartManager.items.length,
            itemBuilder: (context, index) {
              final item = widget.cartManager.items[index];
              return CartItemCard(
                item: item,
                onUpdateQuantity: (newQuantity) {
                  widget.cartManager.updateQuantity(item.product.id, newQuantity);
                },
                onRemove: () {
                  widget.cartManager.removeFromCart(item.product.id);
                },
                onApplyDiscount: () {
                  _showItemDiscountDialog(item);
                },
              );
            },
          ),
        ),

        // Price Breakdown
        if (widget.cartManager.items.isNotEmpty)
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPriceRow('Subtotal', _subtotal),
                  if (_totalDiscount > 0)
                    _buildPriceRow('Total Discount', -_totalDiscount, isDiscount: true),
                  if (_taxAmount > 0)
                    _buildPriceRow('Tax', _taxAmount),
                  Divider(),
                  _buildPriceRow('TOTAL', _finalTotal, isTotal: true),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      children: [
        // Payment Methods
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paymentMethods.map((method) {
                    final isSelected = _selectedPaymentMethod == method;
                    return ChoiceChip(
                      label: Text(_getPaymentMethodName(method)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          if (method == 'credit') {
                            _showCreditSaleModal();
                          } else {
                            setState(() {
                              _selectedPaymentMethod = method;
                              _isCreditSale = false;
                              _creditSaleData = null;
                            });
                          }
                        }
                      },
                      selectedColor: method == 'credit' ? Colors.orange[100] : Colors.blue[100],
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (method == 'credit' ? Colors.orange[800] : Colors.blue[800])
                            : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                if (_isCreditSale && _creditSaleData != null)
                  _buildCreditSaleDetails(),
              ],
            ),
          ),
        ),

        // Additional Options
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Additional Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAdditionalOptionButton(
                        'Additional Discount',
                        _additionalDiscount > 0
                            ? '${Constants.CURRENCY_NAME}${_additionalDiscount.toStringAsFixed(2)}'
                            : 'Add',
                        _showAdditionalDiscountDialog,
                        color: _additionalDiscount > 0 ? Colors.green : null,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildAdditionalOptionButton(
                        'Apply Cart Discount',
                        (widget.cartManager.cartDiscount ?? 0) > 0
                            ? 'Applied'
                            : 'Add',
                        _showCartDiscountDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Final Total
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FINAL TOTAL',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${Constants.CURRENCY_NAME}${_finalTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreditSaleDetails() {
    final creditData = _creditSaleData!;
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Credit Sale Details',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildCreditDetailRow('Amount Paid', creditData.paidAmount),
          _buildCreditDetailRow('Credit Amount', creditData.creditAmount),
        ],
      ),
    );
  }

  Widget _buildCreditDetailRow(String label, double amount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(
            '${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptionButton(
      String title,
      String value,
      VoidCallback onTap, {
        Color? color,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDiscountDialog(CartItem item) {
    final discountAmountController = TextEditingController();
    final discountPercentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Discount to ${item.product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Original Price: ${Constants.CURRENCY_NAME}${item.product.price.toStringAsFixed(2)}'),
            Text('Quantity: ${item.quantity}'),
            SizedBox(height: 16),
            TextField(
              controller: discountAmountController,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 8),
            Text('OR'),
            SizedBox(height: 8),
            TextField(
              controller: discountPercentController,
              decoration: InputDecoration(
                labelText: 'Discount Percentage (%)',
                suffixText: '%',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          if (item.hasManualDiscount)
            TextButton(
              onPressed: () {
                widget.cartManager.removeItemDiscount(item.product.id);
                Navigator.pop(context);
                OverlayManager.showToast(
                  context: context,
                  message: 'Discount removed from ${item.product.name}',
                );
              },
              child: Text('Remove Discount', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final discountAmount = double.tryParse(discountAmountController.text);
              final discountPercent = double.tryParse(discountPercentController.text);
              if (discountAmount != null || discountPercent != null) {
                widget.cartManager.applyItemDiscount(
                  item.product.id,
                  discountAmount: discountAmount,
                  discountPercent: discountPercent,
                );
                Navigator.pop(context);
                OverlayManager.showToast(
                  context: context,
                  message: 'Discount applied to ${item.product.name}',
                );
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  void _showCartDiscountDialog() {
    final discountAmountController = TextEditingController();
    final discountPercentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Cart Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cart Subtotal: ${Constants.CURRENCY_NAME}${_subtotal.toStringAsFixed(2)}'),
            SizedBox(height: 16),
            TextField(
              controller: discountAmountController,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 8),
            Text('OR'),
            SizedBox(height: 8),
            TextField(
              controller: discountPercentController,
              decoration: InputDecoration(
                labelText: 'Discount Percentage (%)',
                suffixText: '%',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          if (widget.cartManager.cartDiscount > 0 || widget.cartManager.cartDiscountPercent > 0)
            TextButton(
              onPressed: () {
                widget.cartManager.removeCartDiscount();
                Navigator.pop(context);
                OverlayManager.showToast(
                  context: context,
                  message: 'Cart discount removed',
                );
              },
              child: Text('Remove Discount', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final discountAmount = double.tryParse(discountAmountController.text);
              final discountPercent = double.tryParse(discountPercentController.text);
              if (discountAmount != null || discountPercent != null) {
                widget.cartManager.applyCartDiscount(
                  discountAmount: discountAmount,
                  discountPercent: discountPercent,
                );
                Navigator.pop(context);
                OverlayManager.showToast(
                  context: context,
                  message: 'Cart discount applied',
                );
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
      String label,
      double amount, {
        bool isDiscount = false,
        bool isTotal = false,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : Colors.black,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}${Constants.CURRENCY_NAME}${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : (isTotal ? Colors.green[700] : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'easypaisa/bank transfer': return 'Easypaisa/Bank Transfer';
      case 'credit': return 'Credit Sale';
      default: return method;
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cart Summary
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_cartItemCount ${_cartItemCount == 1 ? 'Item' : 'Items'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${Constants.CURRENCY_NAME}${_finalTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Navigation Buttons
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isVerySmallScreen = constraints.maxWidth < 200;
                final isSmallScreen = constraints.maxWidth < 250;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavButton(0, Icons.shopping_cart, 'Sell', isSmallScreen, isVerySmallScreen),
                    _buildNavButton(1, Icons.receipt_long, 'Checkout', isSmallScreen, isVerySmallScreen),
                    _buildNavButton(2, Icons.payment, 'Pay', isSmallScreen, isVerySmallScreen),
                  ],
                );
              },
            ),
          ),

          // Process Button
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(6),
              child: _isProcessing
                  ? ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  backgroundColor: Colors.green,
                ),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
                  : ElevatedButton(
                onPressed: widget.cartManager.items.isEmpty ? null : _processOrder,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _currentSection == 2 ? 'COMPLETE' : 'NEXT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(int section, IconData icon, String label, bool isSmallScreen, bool isVerySmallScreen) {
    final isActive = _currentSection == section;

    return Expanded(
      child: InkWell(
        onTap: () => _navigateToSection(section),
        child: Container(
          margin: EdgeInsets.all(2),
          padding: EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? ThemeUtils.primary(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isVerySmallScreen ? 16 : 18,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
              if (!isVerySmallScreen) SizedBox(height: 2),
              if (!isVerySmallScreen)
                Text(
                  _getShortLabel(label, isSmallScreen),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getShortLabel(String label, bool isSmallScreen) {
    if (!isSmallScreen) return label;

    switch (label) {
      case 'Checkout':
        return 'Check';
      case 'Shopping Cart':
        return 'Cart';
      case 'Payment':
        return 'Pay';
      default:
        return label.length > 4 ? label.substring(0, 4) : label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POS System'),
        backgroundColor: ThemeUtils.primary(context),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentSection,
                children: [
                  _buildSellingSection(),
                  _buildCheckoutSection(),
                  _buildPaymentSection(),
                ],
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
class QuickProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onAddToCart;

  const QuickProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<QuickProductCard> createState() => _QuickProductCardState();
}

class _QuickProductCardState extends State<QuickProductCard> {
  double scale = 1.0;

  void _tapDown(_) => setState(() => scale = 0.97);
  void _tapUp(_) => setState(() => scale = 1.0);

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return GestureDetector(
      onTapDown: _tapDown,
      onTapUp: _tapUp,
      onTapCancel: () => setState(() => scale = 1.0),
      onTap: (product.inStock && product.stockQuantity > 0)
          ? widget.onAddToCart
          : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: scale,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 220;
            final isLarge = constraints.maxWidth > 320;

            return Container(
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.4,
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.70),
                    Colors.white.withOpacity(0.45),
                    Colors.white.withOpacity(0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                backgroundBlendMode: BlendMode.overlay,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER → Name + Stock Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: isLarge ? 19 : 16,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 10),
                      _modernStockPill(product),
                    ],
                  ),

                  if (!isCompact && product.categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        children: product.categories.take(2).map(
                              (category) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.blue.withOpacity(0.08),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[900],
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ),

                  const Spacer(),

                  // PRICE
                  Text(
                    '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isLarge ? 24 : 20,
                      color: Colors.green[700],
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.green.withOpacity(0.25),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    product.inStock ? "Tap to add" : "Unavailable",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: product.inStock
                          ? Colors.green[600]
                          : Colors.red[400],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _modernStockPill(Product product) {
    final inStock = product.inStock && product.stockQuantity > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: inStock
              ? [Colors.green.withOpacity(0.22), Colors.green.withOpacity(0.10)]
              : [Colors.red.withOpacity(0.22), Colors.red.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: inStock
              ? Colors.green.withOpacity(0.32)
              : Colors.red.withOpacity(0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: inStock
                ? Colors.green.withOpacity(0.18)
                : Colors.red.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Text(
        inStock ? "${product.stockQuantity}" : "0",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: inStock ? Colors.green[800] : Colors.red[800],
        ),
      ),
    );
  }
}