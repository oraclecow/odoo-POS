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

    test('Arawali 58mm receipt contains exact production header, footer, and zero placeholder text', () async {
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
        cashierName: 'Yani',
        storeName: 'ARAWALI',
        companyId: 1,
      );

      final preview = res['preview'] as String? ?? '';

      // Production Header
      expect(preview.contains('ARAWALI'), isTrue);
      expect(preview.contains('Bima Kota NTB 0811-3909-800'), isTrue);

      // Cashier and Reference
      expect(preview.contains('Yani'), isTrue);
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

      // Production Footer
      expect(preview.contains('Penukaran MAX 1x24 Jam'), isTrue);

      // Zero fake placeholder text
      expect(preview.toLowerCase().contains('palu'), isFalse);
      expect(preview.toLowerCase().contains('pusat belanja keluarga'), isFalse);
      expect(preview.toLowerCase().contains('basuki rahmat'), isFalse);
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
        cashierName: 'Yani',
        storeName: 'ARAWALI',
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

    test('Kartini 58mm receipt contains Pick A Juice header and parking footer', () async {
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
        storeName: 'Pick A Juice Kartini',
        companyId: 6,
      );

      final preview = res['preview'] as String? ?? '';

      // Pick A Juice Header
      expect(preview.contains('Pick A Juice'), isTrue);
      expect(preview.contains('Jl. Kartini No. 10 - Kota Bima'), isTrue);

      // Kartini Footer
      expect(preview.contains('Terima kasih atas kunjungan anda'), isTrue);
      expect(preview.contains('Tunjukkan Resi untuk parkir gratis'), isTrue);
    });
  });
}
