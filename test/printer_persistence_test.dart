import 'package:flutter_test/flutter_test.dart';
import 'package:open_odoo_pos/data/services/printer/printer_service.dart';
import 'package:open_odoo_pos/data/services/printer/printer_settings.dart';
import 'package:open_odoo_pos/data/services/odoo_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Printer Settings & Persistence Tests', () {
    test('Default settings initialize correctly with usbDirect58 preset', () {
      final settings = PrinterSettings();
      expect(settings.connectionType, PrinterConnectionType.usb);
      expect(settings.windowsPrinterName, '58mm Series Printer');
      expect(settings.activePresetId, 'usb_direct_58');
      expect(settings.activeBadgeName, 'USB Local');
    });

    test('Applying eposHttp preset switches connection to ePOS and sets endpoint', () {
      final settings = PrinterSettings();
      settings.applyPreset(PrinterPreset.eposHttp);

      expect(settings.connectionType, PrinterConnectionType.epos);
      expect(settings.activePresetId, 'epos_http');
      expect(settings.eposEndpoint, contains('192.168.1.100'));
      expect(settings.activeBadgeName, 'ePOS (HTTP)');
    });

    test('Applying disabled preset sets silent test mode', () {
      final settings = PrinterSettings();
      settings.applyPreset(PrinterPreset.disabled);

      expect(settings.connectionType, PrinterConnectionType.disabled);
      expect(settings.activeBadgeName, 'Disabled');
    });

    test('PrinterService accepts preloaded settings without race conditions', () {
      final custom = PrinterSettings()
        ..activePresetId = 'epos_http'
        ..connectionType = PrinterConnectionType.epos
        ..eposEndpoint = 'http://192.168.1.100/cgi-bin/epos/service.cgi?devid=local_printer';

      final service = PrinterService(custom);
      expect(service.settings.connectionType, PrinterConnectionType.epos);
      expect(service.settings.activePresetId, 'epos_http');
      expect(service.settings.eposEndpoint, 'http://192.168.1.100/cgi-bin/epos/service.cgi?devid=local_printer');
    });

    test('printCashMoveSlip formats Cash Out voucher cleanly in simulation mode', () async {
      final service = PrinterService(PrinterSettings()..applyPreset(PrinterPreset.disabled));

      final res = await service.printCashMoveSlip(
        type: 'out',
        amount: 50000,
        reason: 'Beli galon air minum',
        cashierName: 'Alice',
      );

      expect(res['success'], true);
      expect(res['simulated'], true);
      final preview = res['preview'] as String?;
      expect(preview, isNotNull);
      expect(preview, contains('CASH OUT VOUCHER'));
      expect(preview, contains('Rp 50.000'));
      expect(preview, contains('Beli galon air minum'));
      expect(preview, contains('Alice'));
    });

    test('printClosingZReport formats Z-Report cleanly in simulation mode', () async {
      final service = PrinterService(PrinterSettings()..applyPreset(PrinterPreset.disabled));

      const closingData = PosClosingControlData(
        orderCount: 12,
        totalSales: 250000.0,
        openingNotes: 'Main Store',
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
        cashierName: 'Alice',
        closingData: closingData,
        countedCash: 250000.0,
        cashDifference: 0.0,
      );

      expect(res['success'], true);
      expect(res['simulated'], true);
      final preview = res['preview'] as String?;
      expect(preview, isNotNull);
      expect(preview, contains('(Z-REPORT)'));
      expect(preview, contains('POS/2026/10/17/0099'));
      expect(preview, contains('Total Penjualan'));
      expect(preview, contains('Rp 250.000'));
    });
  });
}
