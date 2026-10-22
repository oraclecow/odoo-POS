import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/services/printer/printer_service.dart';
import 'package:open_odoo_pos/data/services/printer/printer_settings.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Printer Settings & Persistence Tests', () {
    test('Default settings initialize correctly with cobUsb58 preset', () {
      final settings = PrinterSettings();
      expect(settings.connectionType, PrinterConnectionType.usb);
      expect(settings.windowsPrinterName, '58mm Series Printer');
      expect(settings.activePresetId, 'cob_usb_58');
      expect(settings.activeBadgeName, 'USB Local');
    });

    test('Applying officeCob1 preset switches connection to ePOS and sets endpoint', () {
      final settings = PrinterSettings();
      settings.applyPreset(PrinterPreset.officeCob1);

      expect(settings.connectionType, PrinterConnectionType.epos);
      expect(settings.activePresetId, 'office_cob_1');
      expect(settings.eposEndpoint, contains('192.168.201.193'));
      expect(settings.activeBadgeName, 'COB (Remote)');
    });

    test('Applying disabled preset sets silent test mode', () {
      final settings = PrinterSettings();
      settings.applyPreset(PrinterPreset.disabled);

      expect(settings.connectionType, PrinterConnectionType.disabled);
      expect(settings.activeBadgeName, 'Disabled');
    });

    test('PrinterService accepts preloaded settings without race conditions', () {
      final custom = PrinterSettings()
        ..activePresetId = 'office_cob_1'
        ..connectionType = PrinterConnectionType.epos
        ..eposEndpoint = 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer';

      final service = PrinterService(custom);
      expect(service.settings.connectionType, PrinterConnectionType.epos);
      expect(service.settings.activePresetId, 'office_cob_1');
      expect(service.settings.eposEndpoint, 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer');
    });

    test('printCashMoveSlip formats Cash Out voucher cleanly in simulation mode', () async {
      final service = PrinterService(PrinterSettings()..applyPreset(PrinterPreset.disabled));

      final res = await service.printCashMoveSlip(
        type: 'out',
        amount: 50000,
        reason: 'Beli galon air minum',
        cashierName: 'Ainun',
      );

      expect(res['success'], true);
      expect(res['simulated'], true);
      final preview = res['preview'] as String?;
      expect(preview, isNotNull);
      expect(preview, contains('ARAWALI - KOTA BIMA'));
      expect(preview, isNot(contains('CASH OUT VOUCHER')));
      expect(preview, isNot(contains('Signature:')));
      expect(preview, contains('Rp 50.000'));
      expect(preview, contains('Beli galon air minum'));
      expect(preview, contains('Ainun'));
    });

    test('printClosingZReport formats Z-Report cleanly in simulation mode', () async {
      final service = PrinterService(PrinterSettings()..applyPreset(PrinterPreset.disabled));

      const closingData = PosClosingControlData(
        orderCount: 12,
        totalSales: 250000.0,
        openingNotes: 'Arawali Store',
        openingCash: 100000.0,
        cashPayments: 200000.0,
        cashMovesTotal: -50000.0,
        cashMoves: [],
        expectedCash: 250000.0,
        nonCashMethods: [
          PosNonCashPaymentMethod(id: 2, name: 'QRIS', amount: 50000.0, number: 4, type: 'bank'),
        ],
      );

      final res = await service.printClosingZReport(
        sessionName: 'POS/2026/10/17/0099',
        cashierName: 'Ainun',
        closingData: closingData,
        countedCash: 250000.0,
        cashDifference: 0.0,
      );

      expect(res['success'], true);
      expect(res['simulated'], true);
      final preview = res['preview'] as String?;
      expect(preview, isNotNull);
      expect(preview, contains('ARAWALI'));
      expect(preview, contains('LAPORAN PENUTUPAN KASIR'));
      expect(preview, isNot(contains('(Z-REPORT)')));
      expect(preview, isNot(contains('Supervisor')));
      expect(preview, isNot(contains('Kasir                 Supervisor')));
      expect(preview, contains('POS/2026/10/17/0099'));
      expect(preview, contains('Total Penjualan'));
      expect(preview, contains('Rp 250.000'));
    });

    test('Modular Receipt Engine supports Original Odoo 19 Receipt Format toggle', () async {
      final service = PrinterService(PrinterSettings()..applyPreset(PrinterPreset.disabled));
      service.updateReceiptConfig(
        ReceiptConfig.fromJson({
          'use_odoo_original_format': true,
        }),
      );
      service.updateOdooReceiptMetadata(
        const OdooReceiptMetadata(
          companyName: 'Arawali',
          phone: '+62 812-3456-7890',
          isHeaderOrFooter: true,
          receiptHeader: 'Selamat Datang di Arawali',
          receiptFooter: 'Barang yang sudah dibeli tidak dapat ditukar',
        ),
      );

      final res = await service.printCustomerReceipt(
        orderNumber: 42,
        items: const [],
        totalAmount: 35000,
        paymentMethod: 'Cash',
        tenderedAmount: 50000,
        changeAmount: 15000,
        posReference: 'Order 00042-001-0001',
        cashierName: 'Ainun',
      );

      expect(res['success'], true);
      final preview = res['preview'] as String?;
      expect(preview, isNotNull);
      expect(preview, contains('Arawali'));
      expect(preview, contains('Tel: +62 812-3456-7890'));
      expect(preview, contains('Served by Ainun'));
      expect(preview, contains('Selamat Datang di Arawali'));
      expect(preview, contains('TOTAL'));
      expect(preview, contains('Barang yang sudah dibeli tidak dapat ditukar'));
      expect(preview, contains('Order 00042-001-0001'));
    });

    test('Unified Business Mode (retail vs fnb) & WorkerUiGuardrails configure profiles properly', () {
      final arawali = OdooCompanyProfile.availableProfiles.firstWhere((p) => p.companyId == 1);
      final paj = OdooCompanyProfile.availableProfiles.firstWhere((p) => p.companyId == 6);
      final bakery = OdooCompanyProfile.availableProfiles.firstWhere((p) => p.companyId == 3);

      expect(arawali.mode, PosBusinessMode.retail);
      expect(arawali.guardrails.enableFnbModifiers, false);
      expect(arawali.guardrails.enableKitchenSlip, false);

      expect(paj.mode, PosBusinessMode.fnb);
      expect(paj.guardrails.enableOrderChannels, true);

      expect(bakery.mode, PosBusinessMode.fnb);
      expect(bakery.guardrails.enableFnbModifiers, true);
      expect(bakery.guardrails.enableKitchenSlip, true);
    });
  });
}
