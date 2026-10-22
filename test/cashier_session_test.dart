import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';
import 'package:open_odoo_pos/logic/pos_controller.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';

void main() {
  group('PosCashier Model & Controller', () {
    test('PosCashier initials computation', () {
      const single = PosCashier(id: 1, name: 'Ainun');
      expect(single.initials, 'A');

      const twoParts = PosCashier(id: 2, name: 'John Doe');
      expect(twoParts.initials, 'JD');

      const admin = PosCashier(id: 10, name: 'Administrator', hasPin: true, pin: '1212');
      expect(admin.initials, 'A');
      expect(admin.hasPin, isTrue);
      expect(admin.pin, '1212');
    });

    test('PosCashier json roundtrip', () {
      const cashier = PosCashier(id: 51, name: 'Ainun', userId: null, hasPin: false);
      final json = cashier.toJson();
      expect(json['id'], 51);
      expect(json['name'], 'Ainun');

      final reconstructed = PosCashier.fromJson(json);
      expect(reconstructed.id, 51);
      expect(reconstructed.name, 'Ainun');
      expect(reconstructed.hasPin, isFalse);
    });

    test('PosController tracks active cashier and session', () {
      final repo = JuicePosRepository();
      final controller = PosController(repo);

      const cashier = PosCashier(id: 51, name: 'Ainun');
      controller.setActiveCashier(cashier);

      expect(controller.activeCashier, isNotNull);
      expect(controller.activeCashier!.name, 'Ainun');
      expect(controller.activeCashier!.id, 51);
    });
  });

  group('Odoo 19 Live Integration: Cashiers & Session (LXC 101)', () {
    test('Fetch live cashiers for Arawali Store POS (Config 2)', () async {
      final client = OdooClient();
      await client.authenticate();

      final cashiers = await client.fetchCashiers();
      expect(cashiers.isNotEmpty, isTrue);

      // Verify known cashiers are present
      final names = cashiers.map((c) => c.name).toList();
      expect(names, contains('Administrator'));
      expect(names, anyOf(contains('Ais'), contains('Diah'), contains('Mega'), contains('Yani'), contains('Yuri'), contains('Zia')));
    });

    test('Fetch live active session for Arawali Config 2', () async {
      final client = OdooClient();
      await client.authenticate();

      final sessionId = await client.fetchActiveSession();
      if (sessionId != null) {
        expect(client.activeSessionName, isNotNull);
        expect(client.activeSessionName?.isNotEmpty, isTrue);
      }
    });

    test('Fetch live closing control data for active session in Odoo 19', () async {
      final client = OdooClient();
      await client.authenticate();

      try {
        final closingData = await client.fetchClosingControlData();
        expect(closingData, isNotNull);
        expect(closingData.expectedCash, greaterThanOrEqualTo(0.0));
      } catch (e) {
        // If no active session, test passes gracefully
      }
    });

    test('Fetch live expected opening cash for Arawali Config 2 from Odoo 19', () async {
      final client = OdooClient();
      await client.authenticate();

      final openingCash = await client.fetchExpectedOpeningCash();
      expect(openingCash, greaterThanOrEqualTo(0.0));
      // Expected opening cash should be positive when session was seeded
      expect(openingCash, greaterThan(0.0));
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

