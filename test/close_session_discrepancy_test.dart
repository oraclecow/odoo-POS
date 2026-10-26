import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/models/odoo_pos_models.dart';
import '../lib/modules/pos_session/session_close_view.dart';
import '../lib/logic/pos_controller.dart';
import '../lib/data/repositories/juice_pos_repository.dart';

void main() {
  group('PosCloseResult and PosDiscrepancyException Unit Tests', () {
    test('PosCloseResult retains successful state and discrepancy metadata', () {
      const normalResult = PosCloseResult(success: true);
      expect(normalResult.success, isTrue);
      expect(normalResult.autoForceClosed, isFalse);
      expect(normalResult.amountBalanced, isNull);

      const forceCloseResult = PosCloseResult(
        success: true,
        autoForceClosed: true,
        amountBalanced: 20.0,
        message: 'Force closed 20 IDR discrepancy',
      );
      expect(forceCloseResult.success, isTrue);
      expect(forceCloseResult.autoForceClosed, isTrue);
      expect(forceCloseResult.amountBalanced, equals(20.0));
      expect(forceCloseResult.message, contains('20 IDR'));
    });

    test('PosDiscrepancyException formats descriptive error message', () {
      const exc = PosDiscrepancyException(
        sessionId: 394,
        wizardId: 25,
        amountToBalance: 20.0,
        message: 'There is a difference between the amounts to post and the amounts of the orders',
      );
      expect(exc.sessionId, equals(394));
      expect(exc.wizardId, equals(25));
      expect(exc.amountToBalance, equals(20.0));
      expect(exc.toString(), contains('Selisih pembukuan Odoo Rp 20'));
    });
  });

  group('SessionCloseView Discrepancy UI Tests', () {
    late PosController controller;

    setUp(() {
      controller = PosController(JuicePosRepository());
    });

    testWidgets('Renders Acknowledge & Force Close button when error contains discrepancy message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool forceClosedCalled = false;

      final closingData = PosClosingControlData(
        orderCount: 10,
        totalSales: 500000,
        openingNotes: '',
        openingCash: 200000,
        cashPayments: 300000,
        cashMovesTotal: 0,
        cashMoves: const [],
        expectedCash: 500000,
        nonCashMethods: const [],
        isManager: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionCloseView(
                controller: controller,
                closingData: closingData,
                isLoadingClosingData: false,
                closingDataError: null,
                countedCash: 500000,
                isSubmitting: false,
                errorMessage: 'Selisih pembukuan Odoo terdeteksi: Rp 20. Silakan konfirmasi Tutup Paksa.',
                onRetryLoad: () {},
                onOpenCashOut: () {},
                onPrintZReport: () {},
                onSubmitClose: () {},
                onForceClose: () {
                  forceClosedCalled = true;
                },
                onKeypadPress: (_) {},
                onKeypadBackspace: () {},
                onKeypadClear: () {},
                onKeypadAdd: (_) {},
                onSetExactCash: () {},
              ),
            ),
          ),
        ),
      );

      // Verify that error banner is rendered
      expect(find.textContaining('Selisih pembukuan Odoo terdeteksi'), findsOneWidget);

      // Verify that the Force Close action button is rendered
      final forceCloseBtn = find.text('Acknowledge & Tutup Paksa (Force Close)');
      expect(forceCloseBtn, findsOneWidget);

      // Tap the Force Close button and verify callback
      await tester.tap(forceCloseBtn);
      await tester.pumpAndSettle();

      expect(forceClosedCalled, isTrue);
    });
  });
}
