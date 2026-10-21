import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/ui/widgets/cart_item_quantity_dialog.dart';
import 'package:open_odoo_pos/ui/widgets/payment_dialog.dart';
import 'package:open_odoo_pos/ui/widgets/touch_numpad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartItemQuantityDialog Unit & Widget Tests', () {
    testWidgets('Renders product info, presets, and touch numpad', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartItemQuantityDialog(
              productName: 'Avocado Juice',
              unitPrice: 25000,
              initialQuantity: 1,
              sku: 'AVO-001',
            ),
          ),
        ),
      );

      // Verify Product Header & SKU
      expect(find.text('Avocado Juice'), findsOneWidget);
      expect(find.textContaining('AVO-001'), findsOneWidget);

      // Verify preset chips are present: 1, 10, 12, 24, 48
      expect(find.text('1'), findsWidgets);
      expect(find.text('10'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      expect(find.text('24'), findsWidgets);
      expect(find.text('48'), findsWidgets);

      // Verify numpad keys
      expect(find.byType(TouchNumpad), findsOneWidget);
      expect(find.textContaining('Terapkan'), findsOneWidget);
    });

    testWidgets('Tapping preset updates quantity and subtotal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartItemQuantityDialog(
              productName: 'Mango Juice',
              unitPrice: 20000,
              initialQuantity: 1,
            ),
          ),
        ),
      );

      // Tap preset chip '12'
      final chip12 = find.widgetWithText(InkWell, '12').first;
      await tester.tap(chip12);
      await tester.pump();

      // Quantity should now show 12
      expect(find.text('12'), findsWidgets);
      // Subtotal should be 12 * 20.000 = 240.000
      expect(find.textContaining('240.000'), findsOneWidget);
    });
  });

  group('PaymentDialog Touch & Keyboard Numpad Tests', () {
    testWidgets('Renders checkout total, TouchNumpad, and keyboard shortcut banner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentDialog(
              totalAmount: 50000,
              onConfirmPayment: ({required String paymentMethod, required int tenderedAmount, required int changeAmount}) async {
                return null;
              },
            ),
          ),
        ),
      );

      // Verify Total Due banner
      expect(find.text('Total Due:'), findsOneWidget);
      expect(find.textContaining('50.000'), findsWidgets);

      // Verify TouchNumpad is loaded
      expect(find.byType(TouchNumpad), findsOneWidget);

      // Verify Keyboard shortcuts guide
      expect(find.textContaining('[0-9] Ketik Nominal'), findsOneWidget);
      expect(find.textContaining('[Enter] Bayar'), findsOneWidget);

      // Verify default exact payment ("Pas")
      expect(find.text('Pas'), findsWidgets);
    });

    testWidgets('Touch numpad key press enters cash tendered amount', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentDialog(
              totalAmount: 35000,
              onConfirmPayment: ({required String paymentMethod, required int tenderedAmount, required int changeAmount}) async {
                return null;
              },
            ),
          ),
        ),
      );

      // Find numpad key '5' inside TouchNumpad and tap it
      final key5 = find.descendant(of: find.byType(TouchNumpad), matching: find.text('5'));
      await tester.ensureVisible(key5);
      await tester.tap(key5);
      await tester.pump();

      // Find '000' inside TouchNumpad and tap it
      final key000 = find.descendant(of: find.byType(TouchNumpad), matching: find.text('000'));
      await tester.ensureVisible(key000);
      await tester.tap(key000);
      await tester.pump();

      // Tendered should now be 5.000
      expect(find.textContaining('5.000'), findsWidgets);
    });

    testWidgets('TouchNumpad close register config has +200.000 and omits corner key', (tester) async {
      int added = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouchNumpad(
              onKeyPress: (_) {},
              onBackspace: () {},
              onClear: () {},
              quickAddAmounts: const [10000, 50000, 100000, 200000],
              onQuickAdd: (val) => added += val,
              onExact: () {},
              exactLabel: 'Uang Pas',
              showCornerKey: false,
            ),
          ),
        ),
      );

      // Verify +200.000 chip is present
      expect(find.text('+200.000'), findsOneWidget);
      await tester.tap(find.text('+200.000'));
      expect(added, equals(200000));

      // With showCornerKey: false, the corner grid key should not be present
      // Only the top chip should say 'Uang Pas'
      expect(find.text('Uang Pas'), findsOneWidget);
    });
  });
}

