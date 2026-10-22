import '../models/juice_product.dart';
import '../models/customer.dart';
import '../models/modifier.dart';
import '../services/odoo_client.dart';

class JuicePosRepository {
  final OdooClient? odooClient;

  List<String> _cachedCategories = const [];

  List<JuiceProduct> _cachedProducts = const [];
  List<AddOnOption> _cachedAddOns = const [];

  JuicePosRepository({this.odooClient});

  Future<void> syncWithOdoo() async {
    if (odooClient == null) return;
    try {
      final liveProducts = await odooClient!.fetchPosProducts();
      if (liveProducts.isNotEmpty) _cachedProducts = liveProducts;

      final liveCats = await odooClient!.fetchPosCategories(_cachedProducts);
      _cachedCategories = liveCats;

      final liveAddons = await odooClient!.fetchAddOns();
      if (liveAddons.isNotEmpty) _cachedAddOns = liveAddons;
    } catch (_) {
      // Offline fallback: keep cached catalog
    }
  }

  List<String> getCategories() => _cachedCategories;

  List<JuiceProduct> getProducts() => _cachedProducts.isEmpty ? _defaultProducts : _cachedProducts;

  List<AddOnOption> getAddOns() => _cachedAddOns;

  Future<List<Customer>> searchCustomers(String query) async {
    if (odooClient != null) {
      try {
        final list = await odooClient!.searchCustomers(query);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    // Fallback: search local mock customers by name or phone
    final cleanQuery = query.toLowerCase().replaceAll(RegExp(r'\D'), '');
    final nameQuery = query.toLowerCase().trim();
    return _defaultCustomers.where((c) {
      if (nameQuery.isNotEmpty && c.name.toLowerCase().contains(nameQuery)) return true;
      if (cleanQuery.isNotEmpty && c.phone.replaceAll(RegExp(r'\D'), '').contains(cleanQuery)) return true;
      return false;
    }).toList();
  }

  Future<Customer?> searchCustomer(String phone) async {
    final list = await searchCustomers(phone);
    return list.isNotEmpty ? list.first : null;
  }

  Future<Customer> createCustomer({
    required String name,
    required String phone,
    String? street,
    String? city,
  }) async {
    if (odooClient != null) {
      return await odooClient!.createCustomer(
        name: name,
        phone: phone,
        street: street,
        city: city,
      );
    }
    // Local fallback
    return Customer(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name.trim(),
      phone: phone.trim(),
      tier: 'Member',
      points: 0.0,
    );
  }

  static const List<Customer> _defaultCustomers = [
    Customer(id: 101, name: 'Budi Santoso', phone: '081234567890', tier: 'Gold Member', points: 120),
    Customer(id: 102, name: 'Siti Rahayu', phone: '081398765432', tier: 'Silver Member', points: 45),
    Customer(id: 103, name: 'Ahmad Fauzi', phone: '085611223344', tier: 'Platinum Member', points: 310),
  ];

  Customer? findCustomerByPhone(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    for (final c in _defaultCustomers) {
      if (c.phone.replaceAll(RegExp(r'\D'), '') == cleanPhone) {
        return c;
      }
    }
    return null;
  }

  static const List<JuiceProduct> _defaultProducts = [];
}
