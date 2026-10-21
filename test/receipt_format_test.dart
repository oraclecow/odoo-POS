import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/models/juice_product.dart';
import 'package:open_odoo_pos/data/models/modifier.dart';
import 'package:open_odoo_pos/data/models/order.dart';
import 'package:open_odoo_pos/data/models/customer.dart';
import 'package:open_odoo_pos/data/services/printer/printer_service.dart';
import 'package:open_odoo_pos/data/services/printer/printer_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Receipt Formatting & Odoo 19 Template Compliance', () {
    late PrinterService printer;

    setUp(() {
      printer = PrinterService();
      printer.settings.applyPreset(PrinterPreset.disabled);
    });

    test('58mm receipt contains custom store header, footer, and line details', () async {
      final items = [
        CartItem(
          lineId: '1',
          product: const JuiceProduct(id: 1, name: 'KENTANG GORENG SHOESTRING', price: 20000, category: 'Makanan'),
          modifiers: const SelectedModifiers(),
          quantity: 1,
        ),
      ];

      final res = await printer.printCustomerReceipt(
        orderNumber: 123,
        posReference: 'Order 2611-1-000123',
        items: items,
        totalAmount: 20000,
        paymentMethod: 'Cash',
        tenderedAmount: 50000,
        changeAmount: 30000,
        cashierName: 'Alice',
        storeName: 'MAIN STORE POS',
        companyId: 1,
        customHeader: '123 Retail Blvd • 0800-123-456',
        customFooter: 'Exchange within 24 hours with receipt',
      );

      final preview = res['preview'] as String? ?? '';

      // Header
      expect(preview.contains('MAIN STORE POS'), isTrue);
      expect(preview.contains('123 Retail Blvd'), isTrue);

      // Cashier and Reference
      expect(preview.contains('Alice'), isTrue);
      expect(preview.contains('Order 2611-1-000123'), isTrue);

      // Line format: Clean uppercase product name, indented qty X price
      expect(preview.contains('KENTANG GORENG SHOESTRING'), isTrue);
      expect(preview.contains('1 X Rp 20.000'), isTrue);

      // Totals
      expect(preview.contains('Grand Total'), isTrue);
      expect(preview.contains('20.000'), isTrue);
      expect(preview.contains('Bayar'), isTrue);
      expect(preview.contains('50.000'), isTrue);
      expect(preview.contains('Kembali'), isTrue);
      expect(preview.contains('30.000'), isTrue);

      // Custom Footer
      expect(preview.contains('Exchange within 24 hours with receipt'), isTrue);
    });

    test('Receipt correctly displays discount, loyalty points and return badges', () async {
      final items = [
        CartItem(
          lineId: '1',
          product: const JuiceProduct(id: 1, name: 'MINYAK GORENG 2L', price: 40000, category: 'Sembako'),
          modifiers: const SelectedModifiers(),
          quantity: 2,
        ),
        CartItem(
          lineId: '2',
          product: const JuiceProduct(id: 2, name: 'SABUN CUCI PIRING', price: 15000, category: 'Household'),
          modifiers: const SelectedModifiers(),
          quantity: -1, // Return item
        ),
      ];

      const customer = Customer(
        id: 99,
        name: 'Pak Ahmad',
        phone: '08112345678',
        points: 50000.0,
      );

      final res = await printer.printCustomerReceipt(
        orderNumber: 124,
        posReference: 'Order 2611-1-000124',
        items: items,
        totalAmount: 50000,
        paymentMethod: 'QRIS',
        tenderedAmount: 50000,
        changeAmount: 0,
        orderDiscount: 5000,
        orderDiscountPercent: 0.0,
        pointsDiscount: 10000,
        redeemedPoints: 10000,
        customer: customer,
        cashierName: 'Alice',
        storeName: 'MAIN STORE POS',
        companyId: 1,
      );

      final preview = res['preview'] as String? ?? '';

      // Return line marked with [RETUR]
      expect(preview.contains('[RETUR] SABUN CUCI PIRING'), isTrue);

      // Member info and points balance
      expect(preview.contains('Pak Ahmad'), isTrue);
      expect(preview.contains('50000 Poin'), isTrue);

      // Discounts printed
      expect(preview.contains('Diskon'), isTrue);
      expect(preview.contains('5.000'), isTrue);
      expect(preview.contains('Tukar 10000 Pts'), isTrue);
      expect(preview.contains('10.000'), isTrue);
    });

    test('Branch 58mm receipt supports multi-store custom header and footer', () async {
      final items = [
        CartItem(
          lineId: '1',
          product: const JuiceProduct(id: 1, name: 'AVOCADO LOVER', price: 25000, category: 'Juice'),
          modifiers: const SelectedModifiers(),
          quantity: 1,
        ),
      ];

      final res = await printer.printCustomerReceipt(
        orderNumber: 55,
        posReference: 'Order 2611-6-000055',
        items: items,
        totalAmount: 25000,
        paymentMethod: 'Cash',
        tenderedAmount: 30000,
        changeAmount: 5000,
        cashierName: 'Staff',
        storeName: 'Fresh Juice Bar',
        companyId: 6,
        customHeader: '456 Market Street',
        customFooter: 'Thank you for visiting!\nShow receipt for free parking',
      );

      final preview = res['preview'] as String? ?? '';

      // Custom Store Header
      expect(preview.contains('Fresh Juice Bar'), isTrue);
      expect(preview.contains('456 Market Street'), isTrue);

      // Custom Store Footer
      expect(preview.contains('Thank you for visiting!'), isTrue);
      expect(preview.contains('Show receipt for free parking'), isTrue);
    });
  });
}
