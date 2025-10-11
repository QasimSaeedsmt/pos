// // enhanced_cart_manager.dart
// import 'dart:async';
//
// import 'local_database.dart';
// import 'app.dart' hide LocalDatabase;
//
// class EnhancedCartManager {
//   final List<CartItem> _items = [];
//   final StreamController<List<CartItem>> _cartController = StreamController<List<CartItem>>.broadcast();
//   final StreamController<int> _itemCountController = StreamController<int>.broadcast();
//   final LocalDatabase _localDb = LocalDatabase();
//   bool _isInitialized = false;
//
//   Stream<List<CartItem>> get cartStream => _cartController.stream;
//   Stream<int> get itemCountStream => _itemCountController.stream;
//
//   List<CartItem> get items => List.unmodifiable(_items);
//
//   double get totalAmount {
//     return _items.fold(0.0, (sum, item) => sum + item.subtotal);
//   }
//
//   Future<void> initialize() async {
//     if (_isInitialized) return;
//
//     final savedCartItems = await _localDb.getCartItems();
//     _items.clear();
//     _items.addAll(savedCartItems);
//     _notifyListeners();
//     _isInitialized = true;
//   }
//
//   Future<void> addToCart(Product product) async {
//     final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
//
//     if (existingIndex >= 0) {
//       if (_items[existingIndex].quantity < product.stockQuantity) {
//         _items[existingIndex].quantity++;
//         await _localDb.updateCartItemQuantity(product.id, _items[existingIndex].quantity);
//       } else {
//         throw Exception('Not enough stock available. Only ${product.stockQuantity} left.');
//       }
//     } else {
//       if (product.inStock && product.stockQuantity > 0) {
//         final newItem = CartItem(product: product, quantity: 1);
//         _items.add(newItem);
//         await _localDb.saveCartItem(newItem);
//       } else {
//         throw Exception('Product "${product.name}" is out of stock.');
//       }
//     }
//     _notifyListeners();
//   }
//
//   Future<void> updateQuantity(int productId, int newQuantity) async {
//     if (newQuantity <= 0) {
//       await removeFromCart(productId);
//       return;
//     }
//
//     final itemIndex = _items.indexWhere((item) => item.product.id == productId);
//     if (itemIndex >= 0) {
//       final product = _items[itemIndex].product;
//       if (newQuantity <= product.stockQuantity) {
//         _items[itemIndex].quantity = newQuantity;
//         await _localDb.updateCartItemQuantity(productId, newQuantity);
//         _notifyListeners();
//       } else {
//         throw Exception('Only ${product.stockQuantity} items of "${product.name}" in stock.');
//       }
//     }
//   }
//
//   Future<void> removeFromCart(int productId) async {
//     _items.removeWhere((item) => item.product.id == productId);
//     await _localDb.removeCartItem(productId);
//     _notifyListeners();
//   }
//
//   Future<void> clearCart() async {
//     _items.clear();
//     await _localDb.clearCart();
//     _notifyListeners();
//   }
//
//   List<CartItem> getCheckoutItems() {
//     return _items.map((item) => CartItem(
//         product: item.product,
//         quantity: item.quantity
//     )).toList();
//   }
//
//   void _notifyListeners() {
//     if (!_cartController.isClosed) {
//       _cartController.add(List.from(_items));
//     }
//     if (!_itemCountController.isClosed) {
//       _itemCountController.add(_items.length);
//     }
//   }
//
//   void dispose() {
//     _cartController.close();
//     _itemCountController.close();
//   }
// }