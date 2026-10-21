import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/models/juice_product.dart';
import 'package:open_odoo_pos/data/models/modifier.dart';
import 'package:open_odoo_pos/data/models/order.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';
import 'package:open_odoo_pos/logic/pos_controller.dart';

void main() {
  group('PosController & Retail Calculations', () {
    late JuicePosRepository repo;
    late PosController controller;

    setUp(() {
      repo = JuicePosRepository();
      controller = PosController(repo);
    });

    test('Initial state has retail supermarket default values', () {
      expect(controller.activeTab, 'Register');
      expect(controller.selectedCategory, isEmpty);
      expect(controller.channel.type, OrderChannelType.counter);
      expect(controller.cartItems, isEmpty);
      expect(controller.total, 0);
      expect(controller.loyaltyPointsEarned, 0);
    });

    test('Filtering products by category', () {
      const p1 = JuiceProduct(id: 1, name: 'Indomie Goreng', price: 3500, category: 'Mie & Pasta');
      const p2 = JuiceProduct(id: 2, name: 'Bimoli 1L', price: 21000, category: 'Minyak Goreng');
      controller.setProductsForTesting([p1, p2]);

      controller.selectCategory('Mie & Pasta');
      expect(controller.filteredProducts.length, 1);
      expect(controller.filteredProducts.first.name, 'Indomie Goreng');

      controller.selectCategory('Semua');
      expect(controller.filteredProducts.length, 2);
    });

    test('Direct product addition and barcode scanning increments quantity', () {
      const product = JuiceProduct(
        id: 10,
        name: 'Minyak Goreng 2L',
        price: 36000,
        category: 'Minyak',
        barcode: '8991234567890',
      );
      controller.setProductsForTesting([product]);

      // Scan barcode 1st time
      final scanned1 = controller.handleBarcodeScan('8991234567890');
      expect(scanned1, isNotNull);
      expect(controller.cartItems.length, 1);
      expect(controller.cartItems.first.quantity, 1);
      expect(controller.total, 36000);

      // Scan barcode 2nd time -> should increment existing cart item
      final scanned2 = controller.handleBarcodeScan('8991234567890');
      expect(scanned2, isNotNull);
      expect(controller.cartItems.length, 1);
      expect(controller.cartItems.first.quantity, 2);
      expect(controller.total, 72000);
      // Loyalty points: Rp 72.000 / 25.000 = 2 pts
      expect(controller.loyaltyPointsEarned, 2);
    });

    test('Barcode scan matches with leading zero variations and SKU', () {
      const p1 = JuiceProduct(
        id: 11,
        name: 'Gula Pasir 1kg',
        price: 18000,
        category: 'Sembako',
        barcode: '0899887766554',
        defaultCode: 'SKU-GULA-1KG',
      );
      controller.setProductsForTesting([p1]);

      // Match via stripped leading zero
      final m1 = controller.handleBarcodeScan('899887766554');
      expect(m1?.id, 11);

      // Match via exact code with leading zero
      final m2 = controller.handleBarcodeScan('0899887766554');
      expect(m2?.id, 11);

      // Match via SKU
      final m3 = controller.handleBarcodeScan('SKU-GULA-1KG');
      expect(m3?.id, 11);
      expect(controller.cartItems.first.quantity, 3);
    });

    test('Adding product with modifiers calculates correct line and cart total', () {
      const product = JuiceProduct(id: 1, name: 'Apel Fresh', price: 15000, category: 'Buah');
      const modifiers = SelectedModifiers(
        sugar: 'Less Sugar',
        ice: 'Normal',
        skm: 'No SKM',
        addOns: [
          AddOnOption(id: 'whey', name: 'WHEY PROTEIN', extraPrice: 8000),
          AddOnOption(id: 'buah', name: 'Extra Buah', extraPrice: 5000),
        ],
      );

      // 15.000 + 8.000 + 5.000 = 28.000 per unit
      controller.addJuiceItem(product, modifiers, 2);

      expect(controller.cartItems.length, 1);
      final item = controller.cartItems.first;
      expect(item.unitPrice, 28000);
      expect(item.quantity, 2);
      expect(item.lineTotal, 56000);
      expect(controller.total, 56000);
      expect(controller.loyaltyPointsEarned, 2);
    });

    test('Discount percentage calculates correct CartItem total', () {
      const product = JuiceProduct(id: 3, name: 'Beras Premium 5kg', price: 75000, category: 'Beras');
      final item = CartItem(
        lineId: 'line_1',
        product: product,
        modifiers: const SelectedModifiers(),
        quantity: 2,
        discountPercent: 10.0, // 10% discount
      );

      // 75.000 - 10% = 67.500 * 2 = 135.000
      expect(item.unitPrice, 67500);
      expect(item.lineTotal, 135000);
    });

    test('Quantity update and item removal works correctly', () {
      const product = JuiceProduct(id: 2, name: 'Gula Pasir 1kg', price: 17500, category: 'Sembako');
      controller.addProductDirectly(product, 1);

      final lineId = controller.cartItems.first.lineId;
      controller.updateQuantity(lineId, 1); // increment to 2
      expect(controller.cartItems.first.quantity, 2);
      expect(controller.total, 35000);

      controller.updateQuantity(lineId, -2); // decrement to 0 -> should remove
      expect(controller.cartItems, isEmpty);
      expect(controller.total, 0);
    });

    test('Customer membership lookup and assignment', () {
      final customer = repo.findCustomerByPhone('081234567890');
      expect(customer, isNotNull);
      expect(customer!.name, 'Budi Santoso');
      expect(customer.tier, 'Gold Member');

      controller.setCustomer(customer);
      expect(controller.customer?.name, 'Budi Santoso');
    });

    test('Return items create negative cart lines and set isReturnOrder', () {
      const product = JuiceProduct(id: 5, name: 'Susu UHT 1L', price: 20000, category: 'Minuman');
      controller.addReturnItem(product, 2, unitPrice: 20000, returnRef: '008100');

      expect(controller.cartItems.length, 1);
      final item = controller.cartItems.first;
      expect(item.quantity, -2);
      expect(item.lineTotal, -40000);
      expect(controller.subtotal, -40000);
      expect(controller.total, -40000);
      expect(controller.isReturnOrder, isTrue);

      // Decrementing return item removes it if reaches 0
      controller.updateQuantity(item.lineId, 1); // -2 + 1 = -1
      expect(controller.cartItems.first.quantity, -1);
      expect(controller.total, -20000);

      controller.updateQuantity(item.lineId, 1); // -1 + 1 = 0 -> removed
      expect(controller.cartItems, isEmpty);
      expect(controller.total, 0);
    });

    test('Cart percentage and fixed discounts calculate correct net totals', () {
      const product = JuiceProduct(id: 6, name: 'Minyak Goreng 2L', price: 40000, category: 'Sembako');
      controller.addProductDirectly(product, 1); // Subtotal: 40.000

      // 10% discount -> Rp 4.000 off -> Total 36.000
      controller.setOrderDiscount(percent: 10.0);
      expect(controller.orderDiscountTotal, 4000);
      expect(controller.total, 36000);

      // Fixed Rp 5.000 discount -> Total 35.000
      controller.setOrderDiscount(amount: 5000);
      expect(controller.orderDiscountTotal, 5000);
      expect(controller.total, 35000);

      // Clear discount
      controller.clearOrderDiscount();
      expect(controller.orderDiscountTotal, 0);
      expect(controller.total, 40000);
    });

    test('Loyalty point redemption reduces total at 1 pt = Rp 1', () {
      const product = JuiceProduct(id: 7, name: 'Beras 10kg', price: 150000, category: 'Sembako');
      controller.addProductDirectly(product, 1); // Subtotal: 150.000

      // Redeem 25.000 points -> Rp 25.000 discount -> Total 125.000
      controller.setRedeemedPoints(25000);
      expect(controller.redeemedPoints, 25000);
      expect(controller.pointsDiscount, 25000);
      expect(controller.total, 125000);

      // Combined with 10% discount: 150.000 - 15.000 (10%) - 25.000 (pts) = 110.000
      controller.setOrderDiscount(percent: 10.0);
      expect(controller.orderDiscountTotal, 15000);
      expect(controller.total, 110000);

      // Clear points
      controller.clearRedeemedPoints();
      expect(controller.redeemedPoints, 0);
      expect(controller.pointsDiscount, 0);
      expect(controller.total, 135000);
    });

    test('Item-level discounts and line notes can be adjusted per cart item', () {
      const product = JuiceProduct(id: 8, name: 'Jus Alpukat', price: 20000, category: 'Juice');
      controller.addProductDirectly(product, 2); // 2 x 20.000 = 40.000
      final lineId = controller.cartItems.first.lineId;

      // Apply 10% discount on the line -> unit price 18.000 -> line total 36.000
      controller.applyLineDiscount(lineId, 10.0);
      expect(controller.cartItems.first.unitPrice, 18000);
      expect(controller.cartItems.first.originalUnitPrice, 20000);
      expect(controller.cartItems.first.lineTotal, 36000);
      expect(controller.totalLineDiscounts, 4000); // (20.000 - 18.000) * 2
      expect(controller.subtotal, 36000);

      // Set line note
      controller.setLineNote(lineId, 'Less ice');
      expect(controller.cartItems.first.note, 'Less ice');

      // Clear discount
      controller.applyLineDiscount(lineId, 0.0);
      expect(controller.cartItems.first.discountPercent, null);
      expect(controller.cartItems.first.unitPrice, 20000);
      expect(controller.totalLineDiscounts, 0);
      expect(controller.subtotal, 40000);
    });
  });
}

