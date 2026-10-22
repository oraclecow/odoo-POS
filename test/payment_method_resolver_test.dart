import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';

void main() {
  group('Multi-Store Payment Method Dynamic Resolver Tests', () {
    test('Resolves Kartini (Config 14, Co 6) payment methods correctly', () {
      final registry = StorePaymentRegistry(
        posConfigId: 14,
        methods: const [
          PosPaymentMethodInfo(id: 17, name: 'Cash', isCashCount: true, type: 'cash'),
          PosPaymentMethodInfo(id: 19, name: 'QRIS / Transfer', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 29, name: 'GrabFood', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 30, name: 'ShopeeFood', isCashCount: false, type: 'bank'),
        ],
      );

      expect(registry.cashMethod?.id, 17);
      expect(registry.resolveMethod('Cash')?.id, 17);
      expect(registry.resolveMethod('QRIS')?.id, 19);
      expect(registry.resolveMethod('Transfer')?.id, 19);
      expect(registry.resolveMethod('GrabFood')?.id, 29);
      expect(registry.resolveMethod('ShopeeFood')?.id, 30);
    });

    test('Resolves Arawali (Config 2, Co 1) payment methods and rejects unconfigured aggregators', () {
      final registry = StorePaymentRegistry(
        posConfigId: 2,
        methods: const [
          PosPaymentMethodInfo(id: 1, name: 'Cash', isCashCount: true, type: 'cash'),
          PosPaymentMethodInfo(id: 2, name: 'TRANSFER', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 21, name: 'QRIS BCA', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 22, name: 'QRIS Mandiri', isCashCount: false, type: 'bank'),
        ],
      );

      expect(registry.cashMethod?.id, 1);
      expect(registry.resolveMethod('Cash')?.id, 1);
      expect(registry.resolveMethod('QRIS')?.id, 2); // Matches first bank/transfer/qris
      expect(registry.resolveMethod('Transfer')?.id, 2);
      expect(registry.resolveMethod('GrabFood'), isNull);
      expect(registry.resolveMethod('ShopeeFood'), isNull);
    });

    test('Resolves Bakery (Config 6, Co 3) payment methods correctly', () {
      final registry = StorePaymentRegistry(
        posConfigId: 6,
        methods: const [
          PosPaymentMethodInfo(id: 8, name: 'Cash', isCashCount: true, type: 'cash'),
          PosPaymentMethodInfo(id: 26, name: 'TRANSFER', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 27, name: 'QRIS BCA', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 28, name: 'QRIS Mandiri', isCashCount: false, type: 'bank'),
        ],
      );

      expect(registry.cashMethod?.id, 8);
      expect(registry.resolveMethod('Cash')?.id, 8);
      expect(registry.resolveMethod('GrabFood'), isNull);
      expect(registry.resolveMethod('ShopeeFood'), isNull);
    });

    test('Resolves PAJ Santi (Config 13, Co 2) payment methods correctly', () {
      final registry = StorePaymentRegistry(
        posConfigId: 13,
        methods: const [
          PosPaymentMethodInfo(id: 16, name: 'Cash', isCashCount: true, type: 'cash'),
          PosPaymentMethodInfo(id: 23, name: 'TRANSFER', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 24, name: 'QRIS BCA', isCashCount: false, type: 'bank'),
          PosPaymentMethodInfo(id: 25, name: 'QRIS Mandiri', isCashCount: false, type: 'bank'),
        ],
      );

      expect(registry.cashMethod?.id, 16);
      expect(registry.resolveMethod('Cash')?.id, 16);
      expect(registry.resolveMethod('GrabFood'), isNull);
    });

    test('Resolves PAJ SKW (Config 15, Co 7) payment methods correctly', () {
      final registry = StorePaymentRegistry(
        posConfigId: 15,
        methods: const [
          PosPaymentMethodInfo(id: 18, name: 'Cash PAJ SKW', isCashCount: true, type: 'cash'),
          PosPaymentMethodInfo(id: 20, name: 'QRIS / Transfer', isCashCount: false, type: 'bank'),
        ],
      );

      expect(registry.cashMethod?.id, 18);
      expect(registry.resolveMethod('Cash')?.id, 18);
      expect(registry.resolveMethod('QRIS')?.id, 20);
      expect(registry.resolveMethod('GrabFood'), isNull);
    });
  });
}
