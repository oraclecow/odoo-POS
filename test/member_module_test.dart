import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/models/customer.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';
import 'package:open_odoo_pos/modules/pos_members/member_service.dart';

void main() {
  group('POS Member Module Tests', () {
    late JuicePosRepository repository;
    late MemberService memberService;

    setUp(() {
      repository = JuicePosRepository();
      memberService = MemberService(repository: repository);
    });

    test('MemberService validates required fields', () async {
      expect(
        () => memberService.registerMember(name: '', phone: '08123456789'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => memberService.registerMember(name: 'Budi', phone: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('MemberService successfully registers new member in mock/fallback mode', () async {
      final newMember = await memberService.registerMember(
        name: 'Andi Wijaya',
        phone: '082199887766',
        street: 'Jl. Melati No. 5',
      );

      expect(newMember.name, 'Andi Wijaya');
      expect(newMember.phone, '082199887766');
      expect(newMember.tier, 'Member');
      expect(newMember.points, 0.0);
      expect(newMember.id, greaterThan(0));
    });

    test('checkPhoneExists returns existing member if found', () async {
      // 081234567890 belongs to default customer Budi Santoso
      final existing = await memberService.checkPhoneExists('081234567890');
      expect(existing, isNotNull);
      expect(existing!.name, 'Budi Santoso');

      final notFound = await memberService.checkPhoneExists('089900000000');
      expect(notFound, isNull);
    });
  });
}
