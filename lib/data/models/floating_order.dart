import 'package:uuid/uuid.dart';
import 'customer.dart';
import 'order.dart';

/// Represents an active or parked cart/order in the POS (matching Odoo 19 Floating Orders).
class PosFloatingOrder {
  static const _uuid = Uuid();

  final String id;
  int orderNumber;
  final DateTime createdAt;
  final List<CartItem> items;
  Customer? customer;
  String? orderNote;
  double orderDiscountPercent;
  int orderDiscountAmount;
  int redeemedPoints;
  OrderChannel channel;

  PosFloatingOrder({
    String? id,
    required this.orderNumber,
    DateTime? createdAt,
    List<CartItem>? items,
    this.customer,
    this.orderNote,
    this.orderDiscountPercent = 0.0,
    this.orderDiscountAmount = 0,
    this.redeemedPoints = 0,
    this.channel = const OrderChannel(type: OrderChannelType.counter),
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        items = items ?? [];

  /// Total sum of all line totals before order-level discounts
  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Order-level discount amount in IDR
  int get orderDiscountTotal {
    if (orderDiscountPercent > 0) {
      return ((subtotal * orderDiscountPercent) / 100).round();
    }
    return orderDiscountAmount;
  }

  /// Discount from loyalty points (1 point = Rp 1)
  int get pointsDiscount => redeemedPoints;

  /// Tax in IDR (currently 0% for retail supermarket items)
  int get tax => 0;

  /// Net payable total in IDR
  int get total {
    if (subtotal < 0) {
      // Pure or net return order
      return subtotal;
    }
    final afterDiscount = subtotal - orderDiscountTotal - pointsDiscount;
    return afterDiscount < 0 ? 0 : afterDiscount + tax;
  }

  /// Total sum of original prices vs discounted item unit prices
  int get totalLineDiscounts {
    return items.fold(
      0,
      (sum, item) => sum + ((item.originalUnitPrice - item.unitPrice) * item.quantity),
    );
  }

  /// Total units/items count in cart
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity.abs());

  /// Number of distinct line items
  int get lineCount => items.length;

  /// True if any line in the cart is a return item
  bool get isReturnOrder => items.any((item) => item.quantity < 0);

  /// Member points earned on this order
  int get memberPointsEarned => total > 0 ? (total / 25000).floor() : 0;
  int get loyaltyPointsEarned => memberPointsEarned;

  /// Human-friendly display label for tabs (e.g. "Order #1" or customer name)
  String get tabLabel {
    if (customer != null && customer!.name.trim().isNotEmpty) {
      final nameParts = customer!.name.trim().split(' ');
      final shortName = nameParts.first;
      return '#$orderNumber $shortName';
    }
    return 'Order #$orderNumber';
  }
}
