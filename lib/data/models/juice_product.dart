import 'package:flutter/material.dart';

class JuiceProduct {
  final int id;
  final String name;
  final int price;
  final String category;
  final String? barcode;
  final String? defaultCode;
  final int stock;
  final String? uomName;
  final double? qtyAvailable;
  final bool isKit;
  final IconData icon;
  final Color themeColor;
  final bool requiresModifier;
  final int? grabPrice;
  final int? shopeePrice;
  final String? writeDate;
  final int? productTmplId;
  final bool hasImage;

  const JuiceProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.barcode,
    this.defaultCode,
    this.stock = 0,
    this.uomName,
    this.qtyAvailable,
    this.isKit = false,
    this.icon = Icons.inventory_2_outlined,
    this.themeColor = Colors.redAccent,
    this.requiresModifier = false,
    this.grabPrice,
    this.shopeePrice,
    this.writeDate,
    this.productTmplId,
    this.hasImage = false,
  });

  int getPriceForChannel(dynamic channelType) {
    final typeStr = channelType.toString();
    if (typeStr.contains('grabFood') && grabPrice != null && grabPrice! > 0) {
      return grabPrice!;
    }
    if (typeStr.contains('shopeeFood') && shopeePrice != null && shopeePrice! > 0) {
      return shopeePrice!;
    }
    return price;
  }

  /// Builds Odoo 19 image thumbnail URL with cache-busting write_date
  String? getImageUrl(String baseUrl) {
    if (!hasImage) return null;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final unique = (writeDate != null && writeDate!.isNotEmpty)
        ? '&unique=${Uri.encodeComponent(writeDate!)}'
        : '';
    return '$cleanBase/web/image?model=product.product&field=image_128&id=$id$unique';
  }

  JuiceProduct copyWith({
    int? id,
    String? name,
    int? price,
    String? category,
    String? barcode,
    String? defaultCode,
    int? stock,
    String? uomName,
    double? qtyAvailable,
    bool? isKit,
    IconData? icon,
    Color? themeColor,
    bool? requiresModifier,
    int? grabPrice,
    int? shopeePrice,
    String? writeDate,
    int? productTmplId,
    bool? hasImage,
  }) {
    return JuiceProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      defaultCode: defaultCode ?? this.defaultCode,
      stock: stock ?? this.stock,
      uomName: uomName ?? this.uomName,
      qtyAvailable: qtyAvailable ?? this.qtyAvailable,
      isKit: isKit ?? this.isKit,
      icon: icon ?? this.icon,
      themeColor: themeColor ?? this.themeColor,
      requiresModifier: requiresModifier ?? this.requiresModifier,
      grabPrice: grabPrice ?? this.grabPrice,
      shopeePrice: shopeePrice ?? this.shopeePrice,
      writeDate: writeDate ?? this.writeDate,
      productTmplId: productTmplId ?? this.productTmplId,
      hasImage: hasImage ?? this.hasImage,
    );
  }
}
