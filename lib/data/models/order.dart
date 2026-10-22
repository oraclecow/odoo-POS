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

  int get lineTotal => unitPrice * quantity;

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
