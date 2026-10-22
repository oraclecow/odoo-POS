import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/models/juice_product.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';
import 'package:open_odoo_pos/logic/pos_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  HttpOverrides.global = null;

  group('Product Image Model & URL Helper', () {
    test('Product with hasImage generates correct Odoo image URL', () {
      const product = JuiceProduct(
        id: 231,
        name: 'ALAS TART MARMER KOTAK UK 18',
        price: 15000,
        category: 'Arawali Store',
        writeDate: '2026-10-10 01:15:00',
        productTmplId: 231,
        hasImage: true,
      );

      expect(product.hasImage, isTrue);
      final url = product.getImageUrl('http://192.168.201.201:8069');
      expect(url, isNotNull);
      expect(url, contains('/web/image?model=product.product&field=image_128&id=231'));
      expect(url, contains('unique=2026-10-10%2001%3A15%3A00'));
    });

    test('Product without image returns null getImageUrl', () {
      const product = JuiceProduct(
        id: 999,
        name: 'BARANG TANPA GAMBAR',
        price: 5000,
        category: 'Arawali Store',
        hasImage: false,
      );

      expect(product.hasImage, isFalse);
      expect(product.getImageUrl('http://192.168.201.201:8069'), isNull);
    });

    test('Relative base URL for Web proxy works cleanly', () {
      const product = JuiceProduct(
        id: 3153,
        name: 'ABC KCP MANIS',
        price: 25000,
        category: 'Arawali Store',
        writeDate: '2026-10-12 05:22:23',
        hasImage: true,
      );

      final url = product.getImageUrl('');
      expect(url, startsWith('/web/image?model=product.product&field=image_128&id=3153'));
    });
  });

  group('PosController Image Toggle & Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'pos_show_product_images': true});
    });

    test('toggleShowProductImages updates state and listeners', () async {
      final repo = JuicePosRepository();
      final controller = PosController(repo);

      expect(controller.showProductImages, isTrue);

      await controller.toggleShowProductImages(false);
      expect(controller.showProductImages, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pos_show_product_images'), isFalse);

      await controller.toggleShowProductImages(true);
      expect(controller.showProductImages, isTrue);
      expect(prefs.getBool('pos_show_product_images'), isTrue);
    });
  });

  group('Live Odoo 19 Image Metadata Integration', () {
    test('Live fetchPosProducts populates hasImage flag', () async {
      final client = OdooClient();
      final uid = await client.authenticate();
      expect(uid, greaterThan(0));

      final products = await client.fetchPosProducts();
      expect(products.isNotEmpty, isTrue);

      final productsWithImages = products.where((p) => p.hasImage).toList();
      expect(productsWithImages.isNotEmpty, isTrue);
      // We know from Odoo DB that ~1751 products have images
      expect(productsWithImages.length, greaterThan(500));

      // Test that an image URL can be generated for a product with image
      final sample = productsWithImages.first;
      expect(sample.getImageUrl('http://192.168.201.201:8069'), isNotNull);
    });
  });
}
