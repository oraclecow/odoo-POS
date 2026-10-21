import 'package:flutter/material.dart';

class JuiceProduct {
  final int id;
  final String name;
  final int price;
  final String category;
  final String? barcode;
  final String? defaultCode;
  final double? qtyAvailable;
  final bool isKit;
  final IconData icon;
  final Color themeColor;
  final bool requiresModifier;
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
    this.qtyAvailable,
    this.isKit = false,
    this.icon = Icons.inventory_2_outlined,
    this.themeColor = Colors.redAccent,
    this.requiresModifier = false, // Retail products add straight to cart
    this.writeDate,
    this.productTmplId,
    this.hasImage = false,
  });

  /// Builds Odoo 19 image thumbnail URL with cache-busting write_date
  String? getImageUrl(String baseUrl) {
    if (!hasImage) return null;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final unique = (writeDate != null && writeDate!.isNotEmpty)
        ? '&unique=${Uri.encodeComponent(writeDate!)}'
        : '';
    return '$cleanBase/web/image?model=product.product&field=image_128&id=$id$unique';
  }
}
