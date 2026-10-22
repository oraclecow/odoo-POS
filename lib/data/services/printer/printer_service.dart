import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../../core/hardware/esc_pos_builder.dart';
import '../../../modules/pos_receipt/receipt_config.dart';
export '../../../modules/pos_receipt/receipt_config.dart';
import '../../../modules/pos_receipt/templates/cash_move_receipt.dart';
import '../../../modules/pos_receipt/templates/closing_report_receipt.dart';
import '../../../modules/pos_receipt/templates/customer_receipt.dart';
import '../../../modules/pos_receipt/templates/kitchen_receipt.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../odoo_client.dart';
import 'printer_settings.dart';
import 'printer_transport.dart';

final printerServiceProvider = ChangeNotifierProvider<PrinterService>((ref) {
  return PrinterService();
});

class PrinterService extends ChangeNotifier {
  PrinterSettings settings = PrinterSettings();
  ReceiptConfig receiptConfig = const ReceiptConfig();

  PrinterService([PrinterSettings? initialSettings, ReceiptConfig? initialReceiptConfig]) {
    if (initialReceiptConfig != null) {
      receiptConfig = initialReceiptConfig;
    }
    if (initialSettings != null) {
      settings = initialSettings;
    } else {
      init();
    }
  }

  Future<void> init() async {
    settings = await PrinterSettings.load();
    receiptConfig = await ReceiptConfig.load();
    notifyListeners();
  }

  Future<void> reloadReceiptConfig({String? baseUrl}) async {
    receiptConfig = await ReceiptConfig.load(baseUrl: baseUrl);
    notifyListeners();
  }

  void updateReceiptConfig(ReceiptConfig config) {
    receiptConfig = config;
    notifyListeners();
  }

  void updateOdooReceiptMetadata(OdooReceiptMetadata meta) {
    receiptConfig = receiptConfig.copyWith(odooMeta: meta);
    notifyListeners();
  }

  void notifyUpdated() {
    notifyListeners();
  }

  String? getDefaultPrinterName() => PrinterTransport.getDefaultPrinterName();

  int get _maxColumns => settings.paperWidth == PrinterPaperWidth.mm80 ? 48 : 32;
  bool get _is80mm => settings.paperWidth == PrinterPaperWidth.mm80;

  /// Kicks the RJ11 cash drawer connected to thermal printer
  Future<Map<String, dynamic>> kickCashDrawer() async {
    return await _dispatchBytes(
      EscPosBuilder.cmdDrawerKick,
      label: 'Buka Laci (Cash Drawer)',
      textContent: '[KICK CASH DRAWER]',
    );
  }

  Future<Map<String, dynamic>> testPrint() async {
    final doc = EscPosBuilder(cols: _maxColumns);
    doc.title(receiptConfig.customerReceipt.storeName);
    if (receiptConfig.customerReceipt.subtitle.isNotEmpty) {
      doc.centerMultiline(receiptConfig.customerReceipt.subtitle, bold: true);
    }
    doc.centerLine("ARAWALI POS TEST RECEIPT", bold: true);
    doc.divider();

    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    doc.leftLine("Time    : $timeStr");
    doc.leftLine("Connect : ${settings.connectionType.label}");
    doc.leftLine("Width   : ${settings.paperWidth.label}");
    doc.leftLine("Target  : ${settings.ipAddress}:${settings.port}");
    doc.divider();
    doc.centerLine("PRINTER STATUS: READY & OK!", bold: true);

    final built = doc.build(
      autoCutter: settings.autoCutter,
      is80mm: _is80mm,
      trailingBlankLine: true,
    );
    return await _dispatchDocument(built, label: 'Test Print');
  }

  Future<Map<String, dynamic>> printCustomerReceipt({
    required int orderNumber,
    required List<CartItem> items,
    required int totalAmount,
    required String paymentMethod,
    required int tenderedAmount,
    required int changeAmount,
    int orderDiscount = 0,
    double orderDiscountPercent = 0.0,
    int pointsDiscount = 0,
    int redeemedPoints = 0,
    String? posReference,
    String? trackingNumber,
    Customer? customer,
    String? cashierName,
    String storeName = 'ARAWALI',
    int companyId = 1,
  }) async {
    final doc = CustomerReceiptTemplate.buildCustomerReceipt(
      cols: _maxColumns,
      autoCutter: settings.autoCutter,
      is80mm: _is80mm,
      config: receiptConfig,
      orderNumber: orderNumber,
      items: items,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      tenderedAmount: tenderedAmount,
      changeAmount: changeAmount,
      orderDiscount: orderDiscount,
      orderDiscountPercent: orderDiscountPercent,
      pointsDiscount: pointsDiscount,
      redeemedPoints: redeemedPoints,
      posReference: posReference,
      trackingNumber: trackingNumber,
      customer: customer,
      cashierName: cashierName,
      storeName: storeName,
      companyId: companyId,
    );
    return await _dispatchDocument(doc, label: 'Customer Receipt');
  }

  Future<Map<String, dynamic>> printHistoryReceipt({
    required OdooOrderRecord order,
    List<Map<String, dynamic>>? lines,
    String storeName = 'ARAWALI',
    int companyId = 1,
  }) async {
    final doc = CustomerReceiptTemplate.buildHistoryReceipt(
      cols: _maxColumns,
      autoCutter: settings.autoCutter,
      is80mm: _is80mm,
      config: receiptConfig,
      order: order,
      lines: lines,
      storeName: storeName,
      companyId: companyId,
    );
    return await _dispatchDocument(doc, label: 'Reprint #${order.name}');
  }

  Future<Map<String, dynamic>> printKitchenSlip({
    required int orderNumber,
    required List<CartItem> items,
    required String channelName,
    String? posReference,
    String? trackingNumber,
    String? note,
    String? cashierName,
  }) async {
    final doc = KitchenReceiptTemplate.build(
      cols: _maxColumns,
      autoCutter: settings.autoCutter,
      is80mm: _is80mm,
      config: receiptConfig.kitchen,
      orderNumber: orderNumber,
      items: items,
      channelName: channelName,
      posReference: posReference,
      trackingNumber: trackingNumber,
      note: note,
      cashierName: cashierName,
    );
    return await _dispatchDocument(doc, label: 'Kitchen Slip');
  }

  Future<Map<String, dynamic>> printCashMoveSlip({
    required String type, // 'in' or 'out'
    required int amount,
    required String reason,
    String? cashierName,
  }) async {
    final title = type == 'out' ? 'CASH OUT VOUCHER' : 'CASH IN VOUCHER';
    final doc = CashMoveReceiptTemplate.build(
      cols: _maxColumns,
      autoCutter: settings.autoCutter,
      is80mm: _is80mm,
      config: receiptConfig.cashMove,
      type: type,
      amount: amount,
      reason: reason,
      cashierName: cashierName,
    );
    return await _dispatchDocument(doc, label: title);
  }

  Future<Map<String, dynamic>> printClosingZReport({
    required String sessionName,
    required String? cashierName,
    required PosClosingControlData closingData,
    required double countedCash,
    required double cashDifference,
    String storeName = 'ARAWALI',
  }) async {
    final doc = ClosingReportReceiptTemplate.build(
      cols: _maxColumns,
      autoCutter: settings.autoCutter,
      is80mm: _is80mm,
      config: receiptConfig.sessionClose,
      sessionName: sessionName,
      cashierName: cashierName,
      closingData: closingData,
      countedCash: countedCash,
      cashDifference: cashDifference,
      storeNameOverride: storeName,
    );
    return await _dispatchDocument(doc, label: 'Laporan Penutupan Kasir');
  }

  Future<Map<String, dynamic>> _dispatchDocument(
    EscPosDocument doc, {
    required String label,
  }) {
    return _dispatchBytes(
      doc.bytes,
      label: label,
      textContent: doc.previewText,
    );
  }

  Future<Map<String, dynamic>> _dispatchBytes(
    List<int> bytes, {
    required String label,
    String? textContent,
  }) async {
    if (settings.connectionType == PrinterConnectionType.disabled) {
      return {
        'success': true,
        'simulated': true,
        'preview': textContent,
        'message': 'Cetak dinonaktifkan (Silent Mode). Transaksi selesai.',
      };
    }

    if (settings.connectionType == PrinterConnectionType.usb) {
      return await PrinterTransport.sendUsbBytes(
        bytes,
        printerName: settings.windowsPrinterName,
        label: label,
      );
    }

    if (settings.connectionType == PrinterConnectionType.bluetooth) {
      return {
        'success': true,
        'simulated': false,
        'message': 'Cetak Bluetooth ($label) diproses untuk ${settings.bluetoothName}.',
      };
    }

    if (settings.connectionType == PrinterConnectionType.epos) {
      final xml = EscPosBuilder.buildEposXml(
        textContent: textContent,
        bytes: bytes,
        autoCutter: settings.autoCutter,
        is80mm: _is80mm,
      );
      return await PrinterTransport.sendEposXml(
        endpoint: settings.eposEndpoint,
        xml: xml,
      );
    }

    // Default: TCP RAW 9100 / Socket
    return await PrinterTransport.sendRawBytes(
      host: settings.ipAddress,
      port: settings.port,
      bytes: bytes,
    );
  }
}
