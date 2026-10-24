import 'order.dart';

class IncomingDeliveryItem {
  final String rawName;
  final int quantity;
  final int? price;
  final String? note;
  final String? modifiers;
  final int? matchedProductId;
  final String? matchedProductName;
  final double matchConfidence;

  const IncomingDeliveryItem({
    required this.rawName,
    this.quantity = 1,
    this.price,
    this.note,
    this.modifiers,
    this.matchedProductId,
    this.matchedProductName,
    this.matchConfidence = 0.0,
  });

  bool get isMatched => matchedProductId != null;

  IncomingDeliveryItem copyWith({
    String? rawName,
    int? quantity,
    int? price,
    String? note,
    String? modifiers,
    int? matchedProductId,
    String? matchedProductName,
    double? matchConfidence,
  }) {
    return IncomingDeliveryItem(
      rawName: rawName ?? this.rawName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      note: note ?? this.note,
      modifiers: modifiers ?? this.modifiers,
      matchedProductId: matchedProductId ?? this.matchedProductId,
      matchedProductName: matchedProductName ?? this.matchedProductName,
      matchConfidence: matchConfidence ?? this.matchConfidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': rawName,
    'quantity': quantity,
    'price': price,
    'note': note,
    'modifiers': modifiers,
    'matched_product_id': matchedProductId,
    'matched_product_name': matchedProductName,
    'match_confidence': matchConfidence,
  };

  factory IncomingDeliveryItem.fromJson(Map<String, dynamic> json) {
    return IncomingDeliveryItem(
      rawName: (json['name'] ?? json['raw_name'] ?? json['item_name'] ?? 'Item').toString(),
      quantity: (json['quantity'] ?? json['qty'] ?? 1) is num
          ? (json['quantity'] ?? json['qty'] ?? 1).toInt()
          : int.tryParse((json['quantity'] ?? json['qty'] ?? 1).toString()) ?? 1,
      price: json['price'] != null
          ? (json['price'] is num ? (json['price'] as num).toInt() : int.tryParse(json['price'].toString()))
          : null,
      note: json['note']?.toString(),
      modifiers: json['modifiers']?.toString() ?? json['options']?.toString(),
      matchedProductId: json['matched_product_id'] as int?,
      matchedProductName: json['matched_product_name'] as String?,
      matchConfidence: (json['match_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class IncomingDeliveryOrder {
  final String id;
  final String orderId; // e.g. "GF-1049" or "#12"
  final OrderChannelType channelType;
  final String customerName;
  final String? customerPhone;
  final String? orderNotes;
  final List<IncomingDeliveryItem> items;
  final int? estimatedTotal;
  final DateTime receivedAt;
  final String source; // "wifi_http" or "on_device_accessibility"

  IncomingDeliveryOrder({
    required this.id,
    required this.orderId,
    required this.channelType,
    this.customerName = 'Pelanggan Online',
    this.customerPhone,
    this.orderNotes,
    required this.items,
    this.estimatedTotal,
    DateTime? receivedAt,
    this.source = 'wifi_http',
  }) : receivedAt = receivedAt ?? DateTime.now();

  String get channelLabel => channelType == OrderChannelType.grabFood ? 'GrabFood' : 'ShopeeFood';

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'platform': channelType == OrderChannelType.grabFood ? 'grabfood' : 'shopeefood',
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'order_notes': orderNotes,
    'items': items.map((it) => it.toJson()).toList(),
    'estimated_total': estimatedTotal,
    'received_at': receivedAt.toIso8601String(),
    'source': source,
  };

  factory IncomingDeliveryOrder.fromJson(Map<String, dynamic> json) {
    final platformStr = (json['platform'] ?? json['channel'] ?? 'grabfood').toString().toLowerCase();
    final channel = platformStr.contains('shopee') ? OrderChannelType.shopeeFood : OrderChannelType.grabFood;

    final rawId = (json['id'] ?? 'deliv_${DateTime.now().millisecondsSinceEpoch}').toString();
    final rawOrderId = (json['order_id'] ?? json['orderId'] ?? json['ref'] ?? '#000').toString();

    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((it) => IncomingDeliveryItem.fromJson(Map<String, dynamic>.from(it as Map)))
        .toList();

    return IncomingDeliveryOrder(
      id: rawId,
      orderId: rawOrderId,
      channelType: channel,
      customerName: (json['customer_name'] ?? json['customer'] ?? 'Pelanggan Online').toString(),
      customerPhone: json['customer_phone']?.toString(),
      orderNotes: (json['order_notes'] ?? json['notes'])?.toString(),
      items: itemsList,
      estimatedTotal: json['estimated_total'] != null
          ? (json['estimated_total'] is num
              ? (json['estimated_total'] as num).toInt()
              : int.tryParse(json['estimated_total'].toString()))
          : null,
      receivedAt: json['received_at'] != null ? DateTime.tryParse(json['received_at'].toString()) : null,
      source: (json['source'] ?? 'wifi_http').toString(),
    );
  }
}
