import 'juice_product.dart';
import 'modifier.dart';

enum OrderChannelType {
  counter,
  dineIn,
  takeAway,
  grabFood,
  shopeeFood,
}

class OrderChannel {
  final OrderChannelType type;
  final String? deliveryPin;

  const OrderChannel({
    required this.type,
    this.deliveryPin,
  });

  String get displayName {
    switch (type) {
      case OrderChannelType.counter:
      case OrderChannelType.dineIn:
        return '🏪 Kasir Toko';
      case OrderChannelType.takeAway:
        return '📦 Take Away';
      case OrderChannelType.grabFood:
        return '🟢 GrabFood #${deliveryPin ?? "----"}';
      case OrderChannelType.shopeeFood:
        return '🟠 ShopeeFood #${deliveryPin ?? "----"}';
    }
  }

  String get cleanDisplayName {
    switch (type) {
      case OrderChannelType.counter:
      case OrderChannelType.dineIn:
        return 'Kasir Toko';
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
    double? discountPercent,
    bool clearDiscount = false,
    int? customUnitPrice,
  }) {
    return CartItem(
      lineId: lineId,
      product: product,
      modifiers: modifiers,
      quantity: quantity ?? this.quantity,
      note: clearNote ? null : (note ?? this.note),
      discountPercent: clearDiscount ? null : (discountPercent ?? this.discountPercent),
      customUnitPrice: customUnitPrice ?? this.customUnitPrice,
    );
  }
}

