import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpcm/core/overlay_manager.dart';
import 'package:mpcm/theme_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import '../../app.dart';
import '../../constants.dart';
import '../checkoutBase/checkout_base.dart';
import '../connectivityBase/local_db_base.dart';
import '../product_selling/product_selling_base.dart';

class CartScreen extends StatefulWidget {
  final EnhancedCartManager cartManager;

  const CartScreen({super.key, required this.cartManager});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _currentCartItems = [];
  double _totalAmount = 0.0;
  double _subtotal = 0.0;
  double _discountAmount = 0.0;
  double _taxAmount = 0.0;
  double _taxRate = 0.0;

  @override
  void initState() {
    super.initState();
    _currentCartItems = List.from(widget.cartManager.items);
    _updateTotals();

    widget.cartManager.cartStream.listen((cartItems) {
      if (mounted) {
        setState(() {
          _currentCartItems = List.from(cartItems);
          _updateTotals();
        });
      }
    });

    widget.cartManager.totalStream.listen((total) {
      if (mounted) {
        setState(() {
          _totalAmount = total;
          _updateTotals();
        });
      }
    });
  }

  void _updateTotals() {
    _subtotal = widget.cartManager.subtotal;
    _discountAmount = widget.cartManager.totalDiscount;
    _taxAmount = widget.cartManager.taxAmount;
    _taxRate = widget.cartManager.taxRate;
    _totalAmount = widget.cartManager.totalAmount;
  }

  void _showManualDiscountDialog(CartItem item) {
    final discountAmountController = TextEditingController();
    final discountPercentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Discount to ${item.product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Original Price: ${Constants.CURRENCY_NAME}${item.product.price.toStringAsFixed(2)}',
            ),
            Text('Quantity: ${item.quantity}'),
            Text(
              'Subtotal: ${Constants.CURRENCY_NAME}${item.baseSubtotal.toStringAsFixed(2)}',
            ),
            SizedBox(height: 16),
            TextField(
              controller: discountAmountController,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountPercentController.clear();
                }
              },
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
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountAmountController.clear();
                }
              },
            ),
          ],
        ),
        actions: [
          if (item.hasManualDiscount)
            TextButton(
              onPressed: () {
                widget.cartManager.removeItemDiscount(item.product.id);
                Navigator.pop(context);
               OverlayManager.showToast(context: context, message: 'Discount removed from ${item.product.name}');
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
              final discountAmount = double.tryParse(
                discountAmountController.text,
              );
              final discountPercent = double.tryParse(
                discountPercentController.text,
              );

              if (discountAmount != null || discountPercent != null) {
                widget.cartManager.applyItemDiscount(
                  item.product.id,
                  discountAmount: discountAmount,
                  discountPercent: discountPercent,
                );
                Navigator.pop(context);
               OverlayManager.showToast(context: context, message: 'Discount applied to ${item.product.name}');
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
            Text(
              'Cart Subtotal: ${Constants.CURRENCY_NAME}${_subtotal.toStringAsFixed(2)}',
            ),
            SizedBox(height: 16),
            TextField(
              controller: discountAmountController,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountPercentController.clear();
                }
              },
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
              onChanged: (value) {
                if (value.isNotEmpty) {
                  discountAmountController.clear();
                }
              },
            ),
          ],
        ),
        actions: [
          if (widget.cartManager.cartDiscount > 0 ||
              widget.cartManager.cartDiscountPercent > 0)
            TextButton(
              onPressed: () {
                widget.cartManager.removeCartDiscount();
                Navigator.pop(context);
               OverlayManager.showToast(context: context, message: 'Cart discount removed');
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
              final discountAmount = double.tryParse(
                discountAmountController.text,
              );
              final discountPercent = double.tryParse(
                discountPercentController.text,
              );

              if (discountAmount != null || discountPercent != null) {
                widget.cartManager.applyCartDiscount(
                  discountAmount: discountAmount,
                  discountPercent: discountPercent,
                );
                Navigator.pop(context);
               OverlayManager.showToast(context: context, message: 'Cart discount applied');
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _currentCartItems.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart'),
        actions: [
          if (!isEmpty)
            IconButton(
              icon: Icon(Icons.discount),
              onPressed: _showCartDiscountDialog,
              tooltip: 'Apply Cart Discount',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _currentCartItems.length,
                    itemBuilder: (context, index) {
                      final item = _currentCartItems[index];
                      return CartItemCard(
                        item: item,
                        onUpdateQuantity: (newQuantity) {
                          _updateItemQuantity(item.product.id, newQuantity);
                        },
                        onRemove: () {
                          _removeItem(item.product.id);
                        },
                        onApplyDiscount: () {
                          _showManualDiscountDialog(item);
                        },
                      );
                    },
                  ),
          ),
          _buildCheckoutSection(isEmpty),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text('Your cart is empty', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection(bool isEmpty) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Price Breakdown
          _buildPriceBreakdown(),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(ThemeUtils.primary(context))

              ),

              onPressed: isEmpty ? null : _proceedToCheckout,
              child: Text(
                'PROCEED TO CHECKOUT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ThemeUtils.textPrimary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Column(
      children: [
        _buildPriceRow('Subtotal', _subtotal),
        if (_discountAmount > 0)
          _buildPriceRow('Discount', -_discountAmount, isDiscount: true),
        if (_taxRate > 0)
          _buildPriceRow('Tax (${_taxRate.toStringAsFixed(1)}%)', _taxAmount),
        Divider(),
        _buildPriceRow('TOTAL', _totalAmount, isTotal: true),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
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
              color: isDiscount
                  ? Colors.green
                  : (isTotal ? Colors.green[700] : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateItemQuantity(String productId, int newQuantity) async {
    try {
      await widget.cartManager.updateQuantity(productId, newQuantity);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
  }

  Future<void> _removeItem(String productId) async {
    await widget.cartManager.removeFromCart(productId);
    _showSnackBar('Item removed from cart', Colors.orange);
  }

  void _proceedToCheckout() {
    final checkoutItems = widget.cartManager.getCheckoutItems();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartManager: widget.cartManager,
          cartItems: checkoutItems,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
 OverlayManager.showToast(context: context, message: message,backgroundColor: color);
  }
}

class EnhancedCartManager {
  final List<CartItem> _items = [];
  final StreamController<List<CartItem>> _cartController =
      StreamController<List<CartItem>>.broadcast();
  final StreamController<int> _itemCountController =
      StreamController<int>.broadcast();
  final StreamController<double> _totalController =
      StreamController<double>.broadcast();
  final LocalDatabase _localDb = LocalDatabase();
  bool _isInitialized = false;

  // Cart-level discounts
  double _cartDiscount = 0.0;
  double _cartDiscountPercent = 0.0;
  double _taxRate = 0.0;

  Stream<List<CartItem>> get cartStream => _cartController.stream;
  Stream<int> get itemCountStream => _itemCountController.stream;
  Stream<double> get totalStream => _totalController.stream;

  List<CartItem> get items => List.unmodifiable(_items);

  // Getters for discounts
  double get cartDiscount => _cartDiscount;
  double get cartDiscountPercent => _cartDiscountPercent;
  double get taxRate => _taxRate;

  // Enhanced total calculations
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.baseSubtotal);
  }

  double get totalDiscount {
    final itemDiscounts = _items.fold(
      0.0,
      (sum, item) => sum + item.discountAmount,
    );
    final cartDiscountAmount =
        _cartDiscount + (subtotal * _cartDiscountPercent / 100);
    return itemDiscounts + cartDiscountAmount;
  }

  double get taxableAmount {
    return subtotal - totalDiscount;
  }

  double get taxAmount {
    return taxableAmount * _taxRate / 100;
  }

  double get totalAmount {
    return taxableAmount + taxAmount;
  }

  // Load settings when initializing
  Future<void> initialize() async {
    if (_isInitialized) return;

    final savedCartItems = await _localDb.getCartItems();
    _items.clear();
    _items.addAll(savedCartItems);

    // Load tax rate from settings
    await _loadTaxRate();

    _notifyListeners();
    _isInitialized = true;
  }

  Future<void> _loadTaxRate() async {
    final prefs = await SharedPreferences.getInstance();
    _taxRate = prefs.getDouble('tax_rate') ?? 0.0;
  }

  // Enhanced add to cart with settings integration
  Future<void> addToCart(Product product) async {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity < product.stockQuantity) {
        _items[existingIndex].quantity++;
        await _localDb.saveCartItems(_items);
      } else {
        throw Exception(
          'Not enough stock available. Only ${product.stockQuantity} left.',
        );
      }
    } else {
      if (product.inStock && product.stockQuantity > 0) {
        final newItem = CartItem(product: product, quantity: 1);
        _items.add(newItem);
        await _localDb.saveCartItems(_items);
      } else {
        throw Exception('Product "${product.name}" is out of stock.');
      }
    }
    _notifyListeners();
  }

  // Apply manual discount to specific item
  Future<void> applyItemDiscount(
    String productId, {
    double? discountAmount,
    double? discountPercent,
  }) async {
    final itemIndex = _items.indexWhere((item) => item.product.id == productId);
    if (itemIndex >= 0) {
      _items[itemIndex].manualDiscount = discountAmount;
      _items[itemIndex].manualDiscountPercent = discountPercent;
      await _localDb.saveCartItems(_items);
      _notifyListeners();
    }
  }

  // Remove manual discount from specific item
  Future<void> removeItemDiscount(String productId) async {
    final itemIndex = _items.indexWhere((item) => item.product.id == productId);
    if (itemIndex >= 0) {
      _items[itemIndex].manualDiscount = null;
      _items[itemIndex].manualDiscountPercent = null;
      await _localDb.saveCartItems(_items);
      _notifyListeners();
    }
  }

  // Apply cart-level discount
  Future<void> applyCartDiscount({
    double? discountAmount,
    double? discountPercent,
  }) async {
    _cartDiscount = discountAmount ?? 0.0;
    _cartDiscountPercent = discountPercent ?? 0.0;
    _notifyListeners();
  }

  // Remove cart-level discount
  Future<void> removeCartDiscount() async {
    _cartDiscount = 0.0;
    _cartDiscountPercent = 0.0;
    _notifyListeners();
  }

  // Update tax rate
  Future<void> updateTaxRate(double newTaxRate) async {
    _taxRate = newTaxRate;
    _notifyListeners();
  }

  // Enhanced checkout items with discount information
  List<CartItem> getCheckoutItems() {
    return _items
        .map(
          (item) => CartItem(
            product: item.product,
            quantity: item.quantity,
            manualDiscount: item.manualDiscount,
            manualDiscountPercent: item.manualDiscountPercent,
          ),
        )
        .toList();
  }

  // Enhanced cart data for order creation
  Map<String, dynamic> getCartDataForOrder() {
    return {
      'items': _items
          .map(
            (item) => {
              'productId': item.product.id,
              'productName': item.product.name,
              'quantity': item.quantity,
              'price': item.product.price,
              'manualDiscount': item.manualDiscount,
              'manualDiscountPercent': item.manualDiscountPercent,
              'subtotal': item.subtotal,
              'baseSubtotal': item.baseSubtotal,
              'discountAmount': item.discountAmount,
            },
          )
          .toList(),
      'subtotal': subtotal,
      'totalDiscount': totalDiscount,
      'taxableAmount': taxableAmount,
      'taxRate': _taxRate,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'cartDiscount': _cartDiscount,
      'cartDiscountPercent': _cartDiscountPercent,
    };
  }

  void _notifyListeners() {
    if (!_cartController.isClosed) {
      _cartController.add(List.from(_items));
    }
    if (!_itemCountController.isClosed) {
      _itemCountController.add(_items.length);
    }
    if (!_totalController.isClosed) {
      _totalController.add(totalAmount);
    }
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(productId);
      return;
    }

    final itemIndex = _items.indexWhere((item) => item.product.id == productId);
    if (itemIndex >= 0) {
      final product = _items[itemIndex].product;
      if (newQuantity <= product.stockQuantity) {
        _items[itemIndex].quantity = newQuantity;
        await _localDb.saveCartItems(_items);
        _notifyListeners();
      } else {
        throw Exception(
          'Only ${product.stockQuantity} items of "${product.name}" in stock.',
        );
      }
    }
  }

  Future<void> removeFromCart(String productId) async {
    _items.removeWhere((item) => item.product.id == productId);
    await _localDb.saveCartItems(_items);
    _notifyListeners();
  }
  void clearAllDiscounts() {
    // Clear item-level discounts
    for (final item in _items) {
      item.manualDiscount = null;
      item.manualDiscountPercent = null;
    }

    // Clear cart-level discounts
    _cartDiscount = 0.0;
    _cartDiscountPercent = 0.0;
  }
  Future<void> clearCart() async {
    _items.clear();
    await _localDb.clearCart();
    clearAllDiscounts();
    _notifyListeners();
  }

  void dispose() {
    _cartController.close();
    _itemCountController.close();
  }
}

class CartItem {
  final Product product;
  int quantity;
  double? manualDiscount; // Manual discount amount for this specific item
  double?
  manualDiscountPercent; // Manual discount percentage for this specific item

  CartItem({
    required this.product,
    required this.quantity,
    this.manualDiscount,
    this.manualDiscountPercent,
  });

  double get baseSubtotal => product.price * quantity;

  double get discountAmount {
    if (manualDiscount != null) {
      return manualDiscount! * quantity;
    } else if (manualDiscountPercent != null) {
      return (product.price * manualDiscountPercent! / 100) * quantity;
    }
    return 0.0;
  }

  double get subtotal => baseSubtotal - discountAmount;

  bool get hasManualDiscount =>
      manualDiscount != null || manualDiscountPercent != null;
}

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final Function(int) onUpdateQuantity;
  final VoidCallback onRemove;
  final VoidCallback onApplyDiscount;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onUpdateQuantity,
    required this.onRemove,
    required this.onApplyDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: item.product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(item.product.imageUrl!),
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
                    item.product.name,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${Constants.CURRENCY_NAME}${item.product.price.toStringAsFixed(2)} each',
                  ),
                  if (item.hasManualDiscount) ...[
                    SizedBox(height: 2),
                    Text(
                      'Discount: ${Constants.CURRENCY_NAME}${item.discountAmount.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuantityControls(),
                      Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.hasManualDiscount)
                            Text(
                              '${Constants.CURRENCY_NAME}${item.baseSubtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            '${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(width: 12),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'discount',
                            child: Row(
                              children: [
                                Icon(Icons.discount, size: 20),
                                SizedBox(width: 8),
                                Text('Apply Discount'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Remove',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'discount':
                              onApplyDiscount();
                              break;
                            case 'remove':
                              onRemove();
                              break;
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove, size: 18),
            onPressed: item.quantity > 1
                ? () => onUpdateQuantity(item.quantity - 1)
                : null,
            padding: EdgeInsets.zero,
          ),
          Text(
            item.quantity.toString(),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18),
            onPressed: () => onUpdateQuantity(item.quantity + 1),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
