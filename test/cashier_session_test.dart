import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';
import 'package:open_odoo_pos/logic/pos_controller.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';

void main() {
  group('PosCashier Model & Controller', () {
    test('PosCashier initials computation', () {
      const single = PosCashier(id: 1, name: 'Alice');
      expect(single.initials, 'A');

      const twoParts = PosCashier(id: 2, name: 'John Doe');
      expect(twoParts.initials, 'JD');

      const admin = PosCashier(id: 10, name: 'Administrator', hasPin: true, pin: '1234');
      expect(admin.initials, 'A');
      expect(admin.hasPin, isTrue);
      expect(admin.pin, '1234');
    });

    test('PosCashier json roundtrip', () {
      const cashier = PosCashier(id: 51, name: 'Alice', userId: null, hasPin: false);
      final json = cashier.toJson();
      expect(json['id'], 51);
      expect(json['name'], 'Alice');

      final reconstructed = PosCashier.fromJson(json);
      expect(reconstructed.id, 51);
      expect(reconstructed.name, 'Alice');
      expect(reconstructed.hasPin, isFalse);
    });

    test('PosController tracks active cashier and session', () {
      final repo = JuicePosRepository();
      final controller = PosController(repo);

      const cashier = PosCashier(id: 51, name: 'Alice');
      controller.setActiveCashier(cashier);

      expect(controller.activeCashier, isNotNull);
      expect(controller.activeCashier!.name, 'Alice');
      expect(controller.activeCashier!.id, 51);
    });
  });

  group('PosClosingControlData Model Unit Tests', () {
    test('Parses Odoo 19 get_closing_control_data JSON response properly', () {
      final mockJson = {
        'orders_details': {'quantity': 3, 'amount': 45000.0},
        'opening_notes': 'Modal Awal',
        'default_cash_details': {
          'name': 'Cash',
          'amount': 135000.0,
          'opening': 100000.0,
          'payment_amount': 45000.0,
          'moves': [
            {'name': 'Beli Es', 'amount': -10000.0, 'id': 99}
          ],
          'id': 17
        },
        'non_cash_payment_methods': [
          {'name': 'QRIS / Transfer', 'amount': 25000.0, 'number': 2, 'id': 19, 'type': 'bank'}
        ],
        'is_manager': true
      };

      final data = PosClosingControlData.fromJson(mockJson);
      expect(data.orderCount, 3);
      expect(data.totalSales, 45000.0);
      expect(data.openingCash, 100000.0);
      expect(data.cashPayments, 45000.0);
      expect(data.cashMovesTotal, -10000.0);
      expect(data.expectedCash, 135000.0);
      expect(data.nonCashMethods.length, 1);
      expect(data.nonCashMethods.first.name, 'QRIS / Transfer');
      expect(data.nonCashMethods.first.amount, 25000.0);
      expect(data.nonCashMethods.first.number, 2);
    });
  });
}
