import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/models/order.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';
import 'package:open_odoo_pos/data/services/printer/printer_service.dart';
import 'package:open_odoo_pos/data/services/printer/printer_settings.dart';

void main() {
  group('Operational Ergonomics Unit Tests', () {
    test('OdooOrderRecord.localDateOrder parses and converts UTC date strings to local time', () {
      const utcString = '2026-10-22 01:30:00';
      const record = OdooOrderRecord(
        id: 999,
        name: 'POS/2026/10/22/0001',
        posReference: 'Order 999',
        dateOrder: utcString,
        amountTotal: 45000.0,
        partnerName: 'Test Customer',
        state: 'done',
      );

      final localStr = record.localDateOrder;
      expect(localStr, isNotEmpty);
      expect(localStr, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')));

      // Empty string gracefully returns empty
      const emptyRecord = OdooOrderRecord(
        id: 1000,
        name: 'POS/TEST',
        posReference: 'Order 1000',
        dateOrder: '',
        amountTotal: 0.0,
        partnerName: 'Test',
        state: 'draft',
      );
      expect(emptyRecord.localDateOrder, '');
    });

    test('OrderChannel supports up to 10-character alphanumeric GrabFood / ShopeeFood IDs', () {
      const grabChannel = OrderChannel(
        type: OrderChannelType.grabFood,
        deliveryPin: 'GF-9876543',
      );
      expect(grabChannel.deliveryPin?.length, lessThanOrEqualTo(10));
      expect(grabChannel.displayName, contains('GF-9876543'));

      const shopeeChannel = OrderChannel(
        type: OrderChannelType.shopeeFood,
        deliveryPin: 'SF10293847',
      );
      expect(shopeeChannel.deliveryPin?.length, lessThanOrEqualTo(10));
      expect(shopeeChannel.displayName, contains('SF10293847'));
    });

    test('PrinterService.kickCashDrawer executes RJ11 drawer pulse in simulated mode', () async {
      final printer = PrinterService();
      printer.settings.connectionType = PrinterConnectionType.disabled;
      final res = await printer.kickCashDrawer();
      expect(res['success'], isTrue);
      expect(res['simulated'], isTrue);
    });
  });
}
