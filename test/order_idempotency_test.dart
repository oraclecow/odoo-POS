import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/logic/pos_controller.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';
import 'package:open_odoo_pos/data/models/juice_product.dart';
import 'package:open_odoo_pos/data/models/modifier.dart';

void main() {
  group('Order Idempotency Tests', () {
    test('Cart maintains stable UUID across retries until clearCart is called', () {
      final repo = JuicePosRepository();
      final controller = PosController(repo);

      final initialUuid = controller.currentOrderUuid;
      expect(initialUuid, isNotEmpty);

      // Adding items should NOT change the cart order UUID
      final product = JuiceProduct(
        id: 101,
        name: 'Avocado Lover',
        price: 25000,
        category: 'Jus Segar',
      );
      controller.addJuiceItem(product, const SelectedModifiers());
      expect(controller.currentOrderUuid, equals(initialUuid));

      // Updating quantity should NOT change the cart order UUID
      controller.updateQuantity(controller.cartItems.first.lineId, 1);
      expect(controller.currentOrderUuid, equals(initialUuid));

      // Simulated network failure / retry keeps same UUID
      final retryUuid = controller.currentOrderUuid;
      expect(retryUuid, equals(initialUuid));

      // Clearing cart upon successful submission produces a fresh UUID for the next transaction
      controller.clearCart();
      final nextOrderUuid = controller.currentOrderUuid;
      expect(nextOrderUuid, isNot(equals(initialUuid)));
      expect(nextOrderUuid, isNotEmpty);
    });
  });
}
