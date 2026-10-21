import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';

void main() {
  test('OdooClient initializes with default configuration', () {
    final client = OdooClient();
    expect(client.baseUrl, 'http://localhost:8069');
    expect(client.database, 'odoo');
    expect(client.profile.login, 'admin');
    expect(client.profile.companyId, 1);
    expect(client.profile.posConfigId, 1);
  });
}
