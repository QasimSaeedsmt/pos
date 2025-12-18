import 'package:mpcm/core/models/product_model.dart';

import 'package:hive/hive.dart';

part 'cart_item_model.g.dart';

@HiveType(typeId: 10)
class CartItem {
  @HiveField(0)
  final Product product;

  @HiveField(1)
  int quantity;

  @HiveField(2)
   double? manualDiscount;

  @HiveField(3)
   double? manualDiscountPercent;

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

  // Optional: Helper method to update quantity
  CartItem copyWith({
    Product? product,
    int? quantity,
    double? manualDiscount,
    double? manualDiscountPercent,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      manualDiscountPercent: manualDiscountPercent ?? this.manualDiscountPercent,
    );
  }

  // Optional: Helper method to increase quantity
  CartItem increaseQuantity(int amount) {
    return copyWith(quantity: quantity + amount);
  }

  // Optional: Helper method to decrease quantity
  CartItem decreaseQuantity(int amount) {
    return copyWith(quantity: quantity - amount);
  }

  // Optional: For debugging/logging
  @override
  String toString() {
    return 'CartItem{product: $product, quantity: $quantity, manualDiscount: $manualDiscount, manualDiscountPercent: $manualDiscountPercent}';
  }
}