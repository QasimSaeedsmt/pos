import 'invoice_model.dart';

class DiscountCalculator {
  static Map<String, double> calculateAllDiscounts(Invoice invoice) {
    final discounts = <String, double>{};

    // 1. Item-level discounts
    double itemDiscounts = 0.0;
    for (final item in invoice.items) {
      if (item.hasManualDiscount) {
        itemDiscounts += item.discountAmount ?? 0.0;
      }
    }
    if (itemDiscounts > 0) {
      discounts['item_discounts'] = itemDiscounts;
    }

    // 2. Cart-level discounts from enhanced data
    if (invoice.hasEnhancedPricing) {
      final cartData = invoice.enhancedData?['cartData'] as Map<String, dynamic>?;
      if (cartData != null) {
        final cartDiscount = (cartData['cartDiscount'] as num?)?.toDouble() ?? 0.0;
        final cartDiscountPercent = (cartData['cartDiscountPercent'] as num?)?.toDouble() ?? 0.0;
        final cartSubtotal = (cartData['subtotal'] as num?)?.toDouble() ?? invoice.subtotal;

        final totalCartDiscount = cartDiscount + (cartSubtotal * cartDiscountPercent / 100);
        if (totalCartDiscount > 0) {
          discounts['cart_discount'] = totalCartDiscount;
        }
      }

      // 3. Additional discounts
      final additionalDiscount = invoice.additionalDiscountAmount;
      if (additionalDiscount > 0) {
        discounts['additional_discount'] = additionalDiscount;
      }

      // 4. Shipping (treated as negative discount for display)
      if (invoice.shippingAmount > 0) {
        discounts['shipping'] = invoice.shippingAmount;
      }

      // 5. Tip (treated as negative discount for display)
      if (invoice.tipAmount > 0) {
        discounts['tip'] = invoice.tipAmount;
      }
    }

    // 6. Settings-based discount (for backward compatibility)
    final settingsDiscountRate = (invoice.invoiceSettings['discountRate'] as num?)?.toDouble() ?? 0.0;
    final settingsDiscount = invoice.subtotal * settingsDiscountRate / 100;
    if (settingsDiscount > 0) {
      discounts['settings_discount'] = settingsDiscount;
    }

    // 7. Tax (for complete financial breakdown)
    if (invoice.taxAmount > 0) {
      discounts['tax'] = invoice.taxAmount;
    }

    return discounts;
  }

  static double calculateTotalSavings(Invoice invoice) {
    final discounts = calculateAllDiscounts(invoice);
    double totalSavings = 0.0;

    // Sum all discount types (excluding tax, shipping, tip)
    for (final entry in discounts.entries) {
      if (!['tax', 'shipping', 'tip'].contains(entry.key)) {
        totalSavings += entry.value;
      }
    }

    return totalSavings;
  }

  static double calculateNetAmount(Invoice invoice) {
    return invoice.subtotal - calculateTotalSavings(invoice);
  }

  static String getDiscountLabel(String discountType) {
    switch (discountType) {
      case 'item_discounts':
        return 'Item Discounts';
      case 'cart_discount':
        return 'Cart Discount';
      case 'additional_discount':
        return 'Additional Discount';
      case 'settings_discount':
        return 'Standard Discount';
      case 'legacy_discount':
        return 'Discount';
      case 'shipping':
        return 'Shipping';
      case 'tip':
        return 'Tip';
      case 'tax':
        return 'Tax';
      default:
        return discountType.replaceAll('_', ' ').toTitleCase();
    }
  }

  static Map<String, dynamic> getCompletePricingBreakdown(Invoice invoice) {
    final discounts = calculateAllDiscounts(invoice);
    final totalSavings = calculateTotalSavings(invoice);
    final netAmount = calculateNetAmount(invoice);

    return {
      'gross_amount': invoice.subtotal,
      'total_savings': totalSavings,
      'net_amount': netAmount,
      'tax_amount': invoice.taxAmount,
      'shipping_amount': invoice.shippingAmount,
      'tip_amount': invoice.tipAmount,
      'final_total': invoice.totalAmount,
      'discount_breakdown': discounts,
      'has_enhanced_pricing': invoice.hasEnhancedPricing,
    };
  }
}

extension StringExtension on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}