import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/logic/pos_controller.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';
import 'package:open_odoo_pos/data/models/juice_product.dart';
import 'package:open_odoo_pos/data/models/customer.dart';

void main() {
  group('Floating Orders (Multiple Carts) Unit Tests', () {
    late PosController controller;
    late JuicePosRepository repository;

    final productA = JuiceProduct(
      id: 101,
      name: 'Kecap Manis Bango 550ml',
      category: 'Sembako',
      price: 24500,
      barcode: '899999900101',
      defaultCode: 'SKU-KECAP',
    );

    final productB = JuiceProduct(
      id: 102,
      name: 'Minyak Goreng Sania 2L',
      category: 'Sembako',
      price: 36000,
      barcode: '899999900102',
      defaultCode: 'SKU-SANIA',
    );

    setUp(() {
      repository = JuicePosRepository(odooClient: null);
      controller = PosController(repository);
      controller.setProductsForTesting([productA, productB]);
    });

    test('Initial state has exactly 1 active floating order', () {
      expect(controller.floatingOrders.length, equals(1));
      expect(controller.activeOrderIndex, equals(0));
      expect(controller.cartItems, isEmpty);
      expect(controller.orderNumber, equals(1001));
    });

    test('newFloatingOrder creates a second order and sets it active', () {
      controller.addProductDirectly(productA, 2);
      expect(controller.cartItems.length, equals(1));
      expect(controller.total, equals(49000));

      controller.newFloatingOrder();

      expect(controller.floatingOrders.length, equals(2));
      expect(controller.activeOrderIndex, equals(1));
      expect(controller.orderNumber, equals(1002));
      expect(controller.cartItems, isEmpty); // Order 2 is clean
    });

    test('Items in separate floating orders remain completely isolated', () {
      // Order 1: 2x Kecap
      controller.addProductDirectly(productA, 2);
      expect(controller.subtotal, equals(49000));

      // Park Order 1 and open Order 2
      controller.newFloatingOrder();
      expect(controller.cartItems, isEmpty);

      // Order 2: 1x Minyak
      controller.addProductDirectly(productB, 1);
      expect(controller.subtotal, equals(36000));
      expect(controller.cartItems.length, equals(1));

      // Switch back to Order 1
      controller.selectFloatingOrder(0);
      expect(controller.subtotal, equals(49000));
      expect(controller.cartItems.length, equals(1));
      expect(controller.cartItems.first.product.id, equals(101));
      expect(controller.cartItems.first.quantity, equals(2));

      // Switch back to Order 2
      controller.selectFloatingOrder(1);
      expect(controller.subtotal, equals(36000));
      expect(controller.cartItems.first.product.id, equals(102));
    });

    test('Customer and discounts are isolated per floating order', () {
      const custA = Customer(id: 1, name: 'Budi Santoso', phone: '08123456789', points: 5000);
      const custB = Customer(id: 2, name: 'Siti Aminah', phone: '08987654321', points: 10000);

      // Order 1
      controller.addProductDirectly(productA, 1);
      controller.setCustomer(custA);
      controller.setOrderDiscount(percent: 10.0);
      controller.setOrderNote('Packing rapi');

      // Order 2
      controller.newFloatingOrder();
      controller.addProductDirectly(productB, 2);
      controller.setCustomer(custB);
      controller.setOrderDiscount(amount: 5000);

      // Verify Order 2
      expect(controller.customer?.name, equals('Siti Aminah'));
      expect(controller.orderDiscountAmount, equals(5000));
      expect(controller.orderNote, isNull);

      // Verify Order 1 when switched back
      controller.selectFloatingOrder(0);
      expect(controller.customer?.name, equals('Budi Santoso'));
      expect(controller.orderDiscountPercent, equals(10.0));
      expect(controller.orderNote, equals('Packing rapi'));
    });

    test('Discarding/removing a floating order adjusts active index correctly', () {
      controller.addProductDirectly(productA, 1);
      controller.newFloatingOrder();
      controller.addProductDirectly(productB, 1);
      controller.newFloatingOrder();

      expect(controller.floatingOrders.length, equals(3));
      expect(controller.activeOrderIndex, equals(2));

      // Remove Order 3 (last) -> switches to Order 2 (index 1)
      controller.removeFloatingOrder(2);
      expect(controller.floatingOrders.length, equals(2));
      expect(controller.activeOrderIndex, equals(1));
      expect(controller.cartItems.first.product.id, equals(102));

      // Remove Order 1 (index 0) while Order 2 is active
      controller.removeFloatingOrder(0);
      expect(controller.floatingOrders.length, equals(1));
      expect(controller.activeOrderIndex, equals(0));
      expect(controller.cartItems.first.product.id, equals(102));

      // Removing the only remaining order resets it to a clean order
      controller.removeFloatingOrder(0);
      expect(controller.floatingOrders.length, equals(1));
      expect(controller.activeOrderIndex, equals(0));
      expect(controller.cartItems, isEmpty);
    });

    test('clearCart on multiple orders removes completed order and switches to next open order', () {
      // Order 1: Kecap
      controller.addProductDirectly(productA, 1);

      // Order 2: Minyak
      controller.newFloatingOrder();
      controller.addProductDirectly(productB, 1);

      // Cashier pays Order 2 first
      expect(controller.activeOrderIndex, equals(1));
      controller.clearCart();

      // Order 2 should be gone, Order 1 should now be active
      expect(controller.floatingOrders.length, equals(1));
      expect(controller.activeOrderIndex, equals(0));
      expect(controller.cartItems.first.product.id, equals(101));
    });

    test('selectFloatingOrderByUuid correctly activates matching order', () {
      controller.newFloatingOrder();
      final targetUuid = controller.currentOrderUuid;
      controller.newFloatingOrder();

      expect(controller.currentOrderUuid, isNot(equals(targetUuid)));

      controller.selectFloatingOrderByUuid(targetUuid);
      expect(controller.currentOrderUuid, equals(targetUuid));
    });
  });
}
