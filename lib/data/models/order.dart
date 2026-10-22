import 'juice_product.dart';
import 'modifier.dart';

enum OrderChannelType {
  counter,
  retail,
  dineIn,
  takeAway,
  grabFood,
  shopeeFood,
}

class OrderChannel {
  final OrderChannelType type;
  final String? deliveryPin; // Up to 10-char ID for GrabFood / ShopeeFood

  const OrderChannel({
    required this.type,
    this.deliveryPin,
  });

  String get displayName {
    switch (type) {
      case OrderChannelType.counter:
      case OrderChannelType.retail:
        return '🏪 Kasir Toko';
      case OrderChannelType.dineIn:
        return '🍽️ Dine In';
      case OrderChannelType.takeAway:
        return '🥡 Take Away';
      case OrderChannelType.grabFood:
        return '🟢 GrabFood #${deliveryPin ?? "----"}';
      case OrderChannelType.shopeeFood:
        return '🟠 ShopeeFood #${deliveryPin ?? "----"}';
    }
  }

  String get cleanDisplayName {
    switch (type) {
      case OrderChannelType.counter:
      case OrderChannelType.retail:
        return 'Kasir Toko';
      case OrderChannelType.dineIn:
        return 'Dine In';
      case OrderChannelType.takeAway:
        return 'Take Away';
      case OrderChannelType.grabFood:
        return 'GrabFood #${deliveryPin ?? "----"}';
      case OrderChannelType.shopeeFood:
        return 'ShopeeFood #${deliveryPin ?? "----"}';
    }
  }
}

class CartItem {
  final String lineId;
  final JuiceProduct product;
  final SelectedModifiers modifiers;
  int quantity;
  String? note;
  double? discountPercent;
  int? customUnitPrice;

  CartItem({
    required this.lineId,
    required this.product,
    required this.modifiers,
    this.quantity = 1,
    this.note,
    this.discountPercent,
    this.customUnitPrice,
  });

  int get baseUnitPrice => customUnitPrice ?? product.price;

  int get unitPrice {
    final base = customUnitPrice ?? (product.price + modifiers.extraPriceTotal);
    if (discountPercent != null && discountPercent! > 0) {
      return (base * (1.0 - discountPercent! / 100.0)).round();
    }
    return base;
  }

  int get originalUnitPrice => customUnitPrice ?? (product.price + modifiers.extraPriceTotal);

  /// Line total in IDR.
  /// When a percentage discount is applied, it computes (base * quantity * (1.0 - discount / 100.0)).round()
  /// across the full line quantity rather than multiplying pre-rounded unit prices.
  /// This ensures 100% exact parity with Odoo 19's account.tax engine and avoids closing session imbalances.
  int get lineTotal {
    if (discountPercent != null && discountPercent! > 0) {
      final base = customUnitPrice ?? (product.price + modifiers.extraPriceTotal);
      return (base * quantity * (1.0 - discountPercent! / 100.0)).round();
    }
    return unitPrice * quantity;
  }

  CartItem copyWith({
    int? quantity,
    String? note,
    bool clearNote = false,
    JuiceProduct? product,
    double? discountPercent,
    bool clearDiscount = false,
    int? customUnitPrice,
    bool resetCustomPrice = false,
  }) {
    return CartItem(
      lineId: lineId,
      product: product ?? this.product,
      modifiers: modifiers,
      quantity: quantity ?? this.quantity,
      note: clearNote ? null : (note ?? this.note),
      discountPercent: clearDiscount ? null : (discountPercent ?? this.discountPercent),
      customUnitPrice: resetCustomPrice ? null : (customUnitPrice ?? this.customUnitPrice),
    );
  }
}
