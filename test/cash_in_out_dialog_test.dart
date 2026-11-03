import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/repositories/juice_pos_repository.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';
import 'package:open_odoo_pos/data/services/printer/printer_service.dart';
import 'package:open_odoo_pos/data/services/printer/printer_settings.dart';
import 'package:open_odoo_pos/logic/pos_controller.dart';
import 'package:open_odoo_pos/ui/widgets/cash_in_out_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CashInOutDialog Quick Fill Tests', () {
    late PosController controller;
    late OdooClient odooClient;
    late PrinterService printerService;

    setUp(() {
      controller = PosController(JuicePosRepository());
      odooClient = OdooClient();
      final settings = PrinterSettings()..applyPreset(PrinterPreset.disabled);
      printerService = PrinterService(settings);
    });

    testWidgets('Renders updated Cash Out quick reasons and 50k / 100k nominals', (tester) async {
      tester.view.physicalSize = const Size(1340, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CashInOutDialog(
              odooClient: odooClient,
              controller: controller,
              printerService: printerService,
              initialType: 'out',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check quick reasons
      expect(find.text('Top up Kas Kecil'), findsOneWidget);
      expect(find.text('Setoran'), findsOneWidget);
      expect(find.text('Operasional'), findsOneWidget);

      // Verify old reasons are removed
      expect(find.text('Beli Es Batu'), findsNothing);
      expect(find.text('Beli Galon Air'), findsNothing);
      expect(find.text('Beli Plastik/Cup'), findsNothing);
      expect(find.text('Uang Kembalian'), findsNothing);

      // Check quick nominals (+50.000 and +100.000 only)
      expect(find.text('+50.000'), findsOneWidget);
      expect(find.text('+100.000'), findsOneWidget);
      expect(find.text('+10.000'), findsNothing);
      expect(find.text('+20.000'), findsNothing);

      // Tap 'Operasional' chip and verify text updates
      await tester.tap(find.text('Operasional'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Operasional'), findsOneWidget);

      // Tap +50.000 and verify amount updates to Rp 50.000
      await tester.tap(find.text('+50.000'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 50.000'), findsOneWidget);

      // Tap +100.000 and verify amount updates to Rp 150.000
      await tester.tap(find.text('+100.000'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 150.000'), findsOneWidget);
    });

    testWidgets('Toggling to Cash In shows Top up Kas Kecil, Setoran, Operasional', (tester) async {
      tester.view.physicalSize = const Size(1340, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CashInOutDialog(
              odooClient: odooClient,
              controller: controller,
              printerService: printerService,
              initialType: 'in',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Top up Kas Kecil'), findsOneWidget);
      expect(find.text('Setoran'), findsOneWidget);
      expect(find.text('Operasional'), findsOneWidget);
      expect(find.text('Modal Tambahan'), findsNothing);
    });
  });
}
