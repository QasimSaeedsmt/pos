import 'package:mpcm/core/models/product_model.dart';

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
