import '../../data/models/customer.dart';
import '../../data/repositories/juice_pos_repository.dart';

/// MemberService handles customer search, validation, and registration
/// in a decoupled, modular layer for both Retail and FnB modes.
class MemberService {
  final JuicePosRepository repository;

  MemberService({required this.repository});

  /// Check if a phone number already exists in Odoo
  Future<Customer?> checkPhoneExists(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return null;
    return await repository.searchCustomer(cleanPhone);
  }

  /// Register a new member in Odoo
  Future<Customer> registerMember({
    required String name,
    required String phone,
    String? street,
    String? city,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Nama member wajib diisi.');
    }
    if (cleanPhone.isEmpty) {
      throw ArgumentError('Nomor HP/WhatsApp wajib diisi.');
    }

    return await repository.createCustomer(
      name: cleanName,
      phone: cleanPhone,
      street: street,
      city: city,
    );
  }
}
