import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/models/juice_product.dart';
import 'package:open_odoo_pos/data/services/delivery/product_fuzzy_matcher.dart';

void main() {
  group('ProductFuzzyMatcher Tests', () {
    final catalog = [
      const JuiceProduct(
        id: 3947,
        name: 'PEANUT Toast',
        category: 'MAKANAN',
        price: 18000,
      ),
      const JuiceProduct(
        id: 3948,
        name: 'CHOCO Toast',
        category: 'MAKANAN',
        price: 18000,
      ),
      const JuiceProduct(
        id: 3949,
        name: 'CHEESE Toast',
        category: 'MAKANAN',
        price: 18000,
      ),
      const JuiceProduct(
        id: 201,
        name: 'Jus Alpukat',
        category: 'JUS',
        price: 15000,
      ),
      const JuiceProduct(
        id: 202,
        name: 'Jus Mangga',
        category: 'JUS',
        price: 15000,
      ),
      const JuiceProduct(
        id: 501,
        name: 'Roti Cokelat Noura',
        category: 'ROTI',
        price: 12000,
      ),
      const JuiceProduct(
        id: 502,
        name: 'Roti Keju Noura',
        category: 'ROTI',
        price: 12000,
      ),
    ];

    test('Exact match (case-insensitive)', () {
      final match = ProductFuzzyMatcher.findBestMatch('peanut toast', catalog);
      expect(match, isNotNull);
      expect(match!.product.id, equals(3947));
      expect(match.score, greaterThanOrEqualTo(0.95));
    });

    test('Inverted word order (Toast Peanut -> PEANUT Toast)', () {
      final match = ProductFuzzyMatcher.findBestMatch('Toast Peanut', catalog);
      expect(match, isNotNull);
      expect(match!.product.id, equals(3947));
      expect(match.score, greaterThan(0.70));
    });

    test('Prefix / Modifier addition (Jus Alpukat Manis -> Jus Alpukat)', () {
      final match = ProductFuzzyMatcher.findBestMatch('Jus Alpukat Manis', catalog);
      expect(match, isNotNull);
      expect(match!.product.id, equals(201));
      expect(match.score, greaterThan(0.75));
    });

    test('Typo tolerance (Roti Coklat Noura -> Roti Cokelat Noura)', () {
      final match = ProductFuzzyMatcher.findBestMatch('Roti Coklat Noura', catalog);
      expect(match, isNotNull);
      expect(match!.product.id, equals(501));
      expect(match.score, greaterThan(0.75));
    });

    test('Distinct separation (CHOCO Toast vs PEANUT Toast)', () {
      final match = ProductFuzzyMatcher.findBestMatch('Toast Coklat', catalog);
      expect(match, isNotNull);
      expect(match!.product.id, equals(3948)); // CHOCO Toast
    });

    test('Completely unmatched returns null or low score below threshold', () {
      final match = ProductFuzzyMatcher.findBestMatch('Nasi Goreng Kambing', catalog, minThreshold: 0.60);
      expect(match, isNull);
    });
  });
}
