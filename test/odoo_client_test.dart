import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';

void main() {
  test('OdooClient connects and fetches live products from LXC 101 Odoo 19', () async {
    final client = OdooClient();
    final uid = await client.authenticate();
    expect(uid, greaterThan(0));

    final products = await client.fetchPosProducts();
    expect(products.isNotEmpty, isTrue);
    expect(products.first.name.isNotEmpty, isTrue);
    expect(products.first.price, greaterThanOrEqualTo(0));
  });
}
