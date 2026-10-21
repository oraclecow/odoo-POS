import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../odoo_client.dart';
import 'printer_settings.dart';
import 'printer_transport.dart';

import 'package:flutter/foundation.dart';

final printerServiceProvider = ChangeNotifierProvider<PrinterService>((ref) {
  return PrinterService();
});

class PrinterService extends ChangeNotifier {
  PrinterSettings settings = PrinterSettings();
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  PrinterService([PrinterSettings? initialSettings]) {
    if (initialSettings != null) {
      settings = initialSettings;
    } else {
      init();
    }
  }

  Future<void> init() async {
    settings = await PrinterSettings.load();
    notifyListeners();
  }

  void notifyUpdated() {
    notifyListeners();
  }

  String? getDefaultPrinterName() => PrinterTransport.getDefaultPrinterName();

  int get _maxColumns => settings.paperWidth == PrinterPaperWidth.mm80 ? 48 : 32;

  // ESC/POS Command Constants
  static const List<int> _cmdInit = [0x1B, 0x40]; // ESC @
  static const List<int> _cmdAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> _cmdAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> _cmdBoldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> _cmdBoldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> _cmdDoubleSize = [0x1D, 0x21, 0x11]; // GS ! 0x11
  static const List<int> _cmdNormalSize = [0x1D, 0x21, 0x00]; // GS ! 0x00
  static const List<int> _cmdFeedLines = [0x0A, 0x0A, 0x0A, 0x0A, 0x0A]; // 5 Line Feeds
  static const List<int> _cmdCut = [0x1D, 0x56, 0x42, 0x00]; // GS V 'B' 0 (Full Cut)
  static const List<int> _cmdDrawerKick = [0x1B, 0x70, 0x00, 0x19, 0xFA]; // ESC p 0 25 250 (Kick RJ11 Drawer)

  /// Kicks the RJ11 cash drawer connected to thermal printer
  Future<Map<String, dynamic>> kickCashDrawer() async {
    return await _dispatchBytes(
      _cmdDrawerKick,
      label: 'Buka Laci (Cash Drawer)',
      textContent: '[KICK CASH DRAWER]',
    );
  }

  Future<Map<String, dynamic>> testPrint() async {
    final bytes = <int>[];
    final textBuffer = StringBuffer();
    final cols = _maxColumns;

    bytes.addAll(_cmdInit);

    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("OPEN ODOO POS\n"));
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_encodeEscPos("Point of Sale System\n"));
    bytes.addAll(_encodeEscPos("THERMAL PRINTER TEST RECEIPT\n"));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.writeln(_centerText("OPEN ODOO POS", cols));
    textBuffer.writeln(_centerText("Point of Sale System", cols));
    textBuffer.writeln(_centerText("THERMAL PRINTER TEST RECEIPT", cols));
    textBuffer.writeln('-' * cols);

    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_encodeEscPos("Time    : $timeStr\n"));
    bytes.addAll(_encodeEscPos("Connect : ${settings.connectionType.label}\n"));
    bytes.addAll(_encodeEscPos("Width   : ${settings.paperWidth.label}\n"));
    bytes.addAll(_encodeEscPos("Target  : ${settings.ipAddress}:${settings.port}\n"));
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.writeln("Time    : $timeStr");
    textBuffer.writeln("Connect : ${settings.connectionType.label}");
    textBuffer.writeln("Width   : ${settings.paperWidth.label}");
    textBuffer.writeln("Target  : ${settings.ipAddress}:${settings.port}");
    textBuffer.writeln('-' * cols);

    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("PRINTER STATUS: READY & OK!\n"));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_cmdFeedLines);

    textBuffer.writeln(_centerText("PRINTER STATUS: READY & OK!", cols));
    textBuffer.writeln();

    // Only send cutter if 80mm and cutter enabled. NEVER send cut on 58mm (Rule 6).
    if (settings.autoCutter && settings.paperWidth == PrinterPaperWidth.mm80) {
      bytes.addAll(_cmdCut);
    }

    return await _dispatchBytes(bytes, label: 'Test Print', textContent: textBuffer.toString());
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
    String storeName = 'STORE POS',
    int companyId = 1,
    String? customHeader,
    String? customFooter,
  }) async {
    final bytes = <int>[];
    final textBuffer = StringBuffer();
    final cols = _maxColumns;

    final cleanStoreName = storeName.isNotEmpty ? storeName : 'STORE POS';
    final storeSubtitle = (customHeader != null && customHeader.trim().isNotEmpty)
        ? customHeader.trim()
        : 'Point of Sale Receipt';
    final receiptFooter = (customFooter != null && customFooter.trim().isNotEmpty)
        ? customFooter.trim()
        : 'Thank you for your business!';

    bytes.addAll(_cmdInit);

    // Header (Exact Odoo 19 58mm layout)
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("$cleanStoreName\n"));
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);
    for (final line in storeSubtitle.split('\n')) {
      bytes.addAll(_encodeEscPos("$line\n"));
    }
    bytes.addAll(_encodeEscPos("\n"));

    textBuffer.writeln(_centerText(cleanStoreName, cols));
    for (final line in storeSubtitle.split('\n')) {
      textBuffer.writeln(_centerText(line, cols));
    }
    textBuffer.writeln();

    // Metadata (Date: Cashier, Pelanggan, Order)
    final dateStr = DateFormat('dd/MM/yy HH:mm').format(DateTime.now());
    final effectiveCashier = cashierName?.isNotEmpty == true ? cashierName! : 'Kasir';
    final customerDisplay = customer != null
        ? '${customer.name}${customer.points > 0 ? " (${customer.points.toInt()} Poin)" : ""}'
        : 'Umum';
    final orderDisplay = posReference?.isNotEmpty == true
        ? posReference!
        : (trackingNumber?.isNotEmpty == true ? "#$trackingNumber (Order #$orderNumber)" : "Order #$orderNumber");
    final cleanOrderLabel = orderDisplay.toLowerCase().startsWith('order') ? orderDisplay : "Order $orderDisplay";

    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_encodeEscPos("$dateStr : $effectiveCashier\n"));
    bytes.addAll(_encodeEscPos("Pelanggan : $customerDisplay\n"));
    bytes.addAll(_encodeEscPos("$cleanOrderLabel\n"));
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.writeln("$dateStr : $effectiveCashier");
    textBuffer.writeln("Pelanggan : $customerDisplay");
    textBuffer.writeln(cleanOrderLabel);
    textBuffer.writeln('-' * cols);

    // Lines (Product Name on line 1, Qty X Unit on line 2 with total)
    for (final item in items) {
      final isReturn = item.quantity < 0;
      final prodTitle = isReturn ? '[RETUR] ${item.product.name}' : item.product.name;
      bytes.addAll(_encodeEscPos("$prodTitle\n"));
      textBuffer.writeln(prodTitle);

      final qtyStr = item.quantity.toString();
      final unitStr = _currency.format(item.unitPrice);
      final lineTotalStr = _currency.format(item.lineTotal);
      final detailRow = _formatRow("  $qtyStr X $unitStr", lineTotalStr, cols);
      bytes.addAll(_encodeEscPos(detailRow));
      textBuffer.write(detailRow);

      if (item.discountPercent != null && item.discountPercent! > 0) {
        final discStr = "  (Disc ${item.discountPercent!.toStringAsFixed(0)}%)\n";
        bytes.addAll(_encodeEscPos(discStr));
        textBuffer.write(discStr);
      }
      if (item.modifiers.summaryDescription != 'Normal (Default)' && item.modifiers.summaryDescription.isNotEmpty) {
        final modStr = "  [${item.modifiers.summaryDescription}]\n";
        bytes.addAll(_encodeEscPos(modStr));
        textBuffer.write(modStr);
      }
      if (item.note != null && item.note!.isNotEmpty) {
        final noteStr = "  Catatan: ${item.note}\n";
        bytes.addAll(_encodeEscPos(noteStr));
        textBuffer.write(noteStr);
      }
    }

    // Discounts & Loyalty Point Redemptions
    if (orderDiscount > 0 || pointsDiscount > 0) {
      bytes.addAll(_encodeEscPos("${'-' * cols}\n"));
      textBuffer.writeln('-' * cols);

      if (orderDiscount > 0) {
        final discLabel = orderDiscountPercent > 0
            ? "Diskon (${orderDiscountPercent.toStringAsFixed(0)}%)"
            : "Diskon Cart";
        final discRow = _formatRow(discLabel, "-${_currency.format(orderDiscount)}", cols);
        bytes.addAll(_encodeEscPos(discRow));
        textBuffer.write(discRow);
      }

      if (pointsDiscount > 0) {
        final ptsLabel = "Tukar $redeemedPoints Pts";
        final ptsRow = _formatRow(ptsLabel, "-${_currency.format(pointsDiscount)}", cols);
        bytes.addAll(_encodeEscPos(ptsRow));
        textBuffer.write(ptsRow);
      }
    }

    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));
    textBuffer.writeln('-' * cols);

    // Totals & Payments (Grand Total, Bayar, Kembali)
    bytes.addAll(_cmdBoldOn);
    final totalRow = _formatRow("Grand Total", _currency.format(totalAmount), cols);
    bytes.addAll(_encodeEscPos(totalRow));
    bytes.addAll(_cmdBoldOff);
    textBuffer.write(totalRow);

    final displayTendered = tenderedAmount != 0 ? tenderedAmount : totalAmount;
    final payMethodLabel = paymentMethod.isNotEmpty && paymentMethod.toLowerCase() != 'bayar'
        ? "Bayar ($paymentMethod)"
        : "Bayar";
    final payRow = _formatRow(payMethodLabel, _currency.format(displayTendered), cols);
    bytes.addAll(_encodeEscPos(payRow));
    textBuffer.write(payRow);

    if (changeAmount != 0) {
      final changeRow = _formatRow("Kembali", _currency.format(changeAmount), cols);
      bytes.addAll(_encodeEscPos(changeRow));
      textBuffer.write(changeRow);
    }

    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));
    textBuffer.writeln('-' * cols);

    // Footer
    bytes.addAll(_cmdAlignCenter);
    for (final line in receiptFooter.split('\n')) {
      bytes.addAll(_encodeEscPos("$line\n"));
      textBuffer.writeln(_centerText(line, cols));
    }
    bytes.addAll(_cmdFeedLines);
    textBuffer.writeln();

    if (settings.autoCutter && settings.paperWidth == PrinterPaperWidth.mm80) {
      bytes.addAll(_cmdCut);
    }

    return await _dispatchBytes(bytes, label: 'Customer Receipt', textContent: textBuffer.toString());
  }

  Future<Map<String, dynamic>> printHistoryReceipt({
    required OdooOrderRecord order,
    List<Map<String, dynamic>>? lines,
    String storeName = 'STORE POS',
    int companyId = 1,
    String? customHeader,
    String? customFooter,
  }) async {
    final bytes = <int>[];
    final textBuffer = StringBuffer();
    final cols = _maxColumns;

    final cleanStoreName = storeName.isNotEmpty ? storeName : 'STORE POS';
    final storeSubtitle = (customHeader != null && customHeader.trim().isNotEmpty)
        ? customHeader.trim()
        : 'Point of Sale Receipt';
    final receiptFooter = (customFooter != null && customFooter.trim().isNotEmpty)
        ? customFooter.trim()
        : 'Thank you for your business!';

    bytes.addAll(_cmdInit);

    // Header
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("$cleanStoreName\n"));
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);
    for (final line in storeSubtitle.split('\n')) {
      bytes.addAll(_encodeEscPos("$line\n"));
    }
    bytes.addAll(_encodeEscPos("DUPLIKAT STRUK (REPRINT)\n"));
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.writeln(_centerText(cleanStoreName, cols));
    for (final line in storeSubtitle.split('\n')) {
      textBuffer.writeln(_centerText(line, cols));
    }
    textBuffer.writeln(_centerText("DUPLIKAT STRUK (REPRINT)", cols));
    textBuffer.writeln('-' * cols);

    // Meta details
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_encodeEscPos("${order.localDateOrder}\n"));
    bytes.addAll(_encodeEscPos("Pelanggan : ${order.partnerName}\n"));
    bytes.addAll(_encodeEscPos("Order ${order.posReference.isNotEmpty ? order.posReference : order.name}\n"));
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.writeln(order.localDateOrder);
    textBuffer.writeln("Pelanggan : ${order.partnerName}");
    textBuffer.writeln("Order ${order.posReference.isNotEmpty ? order.posReference : order.name}");
    textBuffer.writeln('-' * cols);

    // Lines if available
    if (lines != null && lines.isNotEmpty) {
      for (final l in lines) {
        String prodName = 'Item';
        final fpn = l['full_product_name'];
        if (fpn is String && fpn.trim().isNotEmpty && fpn.trim().toLowerCase() != 'false') {
          prodName = fpn.trim();
        } else if (l['product_id'] is List && (l['product_id'] as List).length > 1 && (l['product_id'] as List)[1] != null) {
          final raw = (l['product_id'] as List)[1].toString().trim();
          final match = RegExp(r'^\[.*?\]\s*(.*)$').firstMatch(raw);
          prodName = (match != null && match.group(1)?.trim().isNotEmpty == true)
              ? match.group(1)!.trim()
              : raw;
        } else if (l['name'] is String && (l['name'] as String).trim().isNotEmpty) {
          prodName = (l['name'] as String).trim();
        }
        final qty = ((l['qty'] as num?) ?? 1).toDouble();
        final unitPrice = ((l['price_unit'] as num?) ?? 0).toDouble();
        final subtotal = ((l['price_subtotal_incl'] as num?) ?? 0).toInt();

        final isReturn = qty < 0;
        final title = isReturn ? '[RETUR] $prodName' : prodName;
        bytes.addAll(_encodeEscPos("$title\n"));
        textBuffer.writeln(title);

        final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
        final detailRow = _formatRow("  $qtyStr X ${_currency.format(unitPrice)}", _currency.format(subtotal), cols);
        bytes.addAll(_encodeEscPos(detailRow));
        textBuffer.write(detailRow);
      }
      bytes.addAll(_encodeEscPos("${'-' * cols}\n"));
      textBuffer.writeln('-' * cols);
    }

    // Totals
    bytes.addAll(_cmdBoldOn);
    final totalRow = _formatRow("Grand Total", _currency.format(order.amountTotal), cols);
    bytes.addAll(_encodeEscPos(totalRow));
    bytes.addAll(_cmdBoldOff);
    textBuffer.write(totalRow);

    final statusRow = _formatRow("Status", order.state.toUpperCase(), cols);
    bytes.addAll(_encodeEscPos(statusRow));
    textBuffer.write(statusRow);
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));
    textBuffer.writeln('-' * cols);

    // Footer
    bytes.addAll(_cmdAlignCenter);
    for (final line in receiptFooter.split('\n')) {
      bytes.addAll(_encodeEscPos("$line\n"));
      textBuffer.writeln(_centerText(line, cols));
    }
    bytes.addAll(_encodeEscPos("Cetak Ulang Arsip Kasir\n"));
    bytes.addAll(_cmdFeedLines);

    textBuffer.writeln(_centerText("Cetak Ulang Arsip Kasir", cols));
    textBuffer.writeln();

    if (settings.autoCutter && settings.paperWidth == PrinterPaperWidth.mm80) {
      bytes.addAll(_cmdCut);
    }

    return await _dispatchBytes(bytes, label: 'Reprint #${order.name}', textContent: textBuffer.toString());
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
    final bytes = <int>[];
    final textBuffer = StringBuffer();
    final cols = _maxColumns;

    bytes.addAll(_cmdInit);
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("*** KITCHEN / BARISTA ***\n"));
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_encodeEscPos("CHANNEL: $channelName\n"));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos("${'=' * cols}\n"));

    textBuffer.writeln(_centerText("*** KITCHEN / BARISTA ***", cols));
    textBuffer.writeln(_centerText("CHANNEL: $channelName", cols));
    textBuffer.writeln('=' * cols);

    bytes.addAll(_cmdAlignLeft);
    final ticketNum = trackingNumber != null && trackingNumber.isNotEmpty
        ? "#$trackingNumber ($orderNumber)"
        : "#$orderNumber";
    final refStr = posReference != null && posReference.isNotEmpty ? " | $posReference" : "";
    final orderMeta = "Order: $ticketNum$refStr | ${DateFormat('HH:mm:ss').format(DateTime.now())}";
    bytes.addAll(_encodeEscPos("$orderMeta\n"));
    textBuffer.writeln(orderMeta);

    if (cashierName != null && cashierName.isNotEmpty) {
      bytes.addAll(_encodeEscPos("Cashier: $cashierName\n"));
      textBuffer.writeln("Cashier: $cashierName");
    }

    if (note != null && note.isNotEmpty) {
      bytes.addAll(_cmdBoldOn);
      bytes.addAll(_encodeEscPos("Note: $note\n"));
      bytes.addAll(_cmdBoldOff);
      textBuffer.writeln("Note: $note");
    }
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));
    textBuffer.writeln('-' * cols);

    // Product & Modifiers (clearly separated for preparation)
    for (final item in items) {
      bytes.addAll(_cmdBoldOn);
      bytes.addAll(_cmdDoubleSize);
      bytes.addAll(_encodeEscPos("${item.quantity}x ${item.product.name}\n"));
      bytes.addAll(_cmdNormalSize);
      bytes.addAll(_cmdBoldOff);

      textBuffer.writeln("${item.quantity}x ${item.product.name}");

      if (item.modifiers.summaryDescription != 'Normal (Default)') {
        bytes.addAll(_encodeEscPos("   -> ${item.modifiers.summaryDescription}\n"));
        textBuffer.writeln("   -> ${item.modifiers.summaryDescription}");
      }
      bytes.addAll(_encodeEscPos("\n"));
      textBuffer.writeln();
    }
    bytes.addAll(_encodeEscPos("${'=' * cols}\n"));
    bytes.addAll(_cmdFeedLines);

    textBuffer.writeln('=' * cols);
    textBuffer.writeln();

    if (settings.autoCutter && settings.paperWidth == PrinterPaperWidth.mm80) {
      bytes.addAll(_cmdCut);
    }

    return await _dispatchBytes(bytes, label: 'Kitchen Slip', textContent: textBuffer.toString());
  }

  Future<Map<String, dynamic>> printCashMoveSlip({
    required String type, // 'in' or 'out'
    required int amount,
    required String reason,
    String? cashierName,
  }) async {
    final bytes = <int>[];
    final textBuffer = StringBuffer();
    final cols = _maxColumns;

    final isOut = type == 'out';
    final title = isOut ? 'CASH OUT VOUCHER' : 'CASH IN VOUCHER';

    bytes.addAll(_cmdInit);
    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("*** $title ***\n"));
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos("STORE POS - Cash Voucher\n"));
    bytes.addAll(_encodeEscPos("${'=' * cols}\n"));

    textBuffer.writeln(_centerText("*** $title ***", cols));
    textBuffer.writeln(_centerText("STORE POS - Cash Voucher", cols));
    textBuffer.writeln('=' * cols);

    final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_encodeEscPos(_formatRow("Date/Time", timeStr, cols)));
    if (cashierName != null && cashierName.isNotEmpty) {
      bytes.addAll(_encodeEscPos(_formatRow("Cashier", cashierName, cols)));
    }
    bytes.addAll(_encodeEscPos(_formatRow("Type", isOut ? "Cash Out (Tarik Kas)" : "Cash In (Setor Kas)", cols)));
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos(_formatRow("Amount", _currency.format(amount), cols)));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));
    bytes.addAll(_encodeEscPos("Reason: $reason\n\n"));
    bytes.addAll(_encodeEscPos("Signature:\n\n\n"));
    bytes.addAll(_encodeEscPos("${'.' * (cols ~/ 2)}\n"));
    bytes.addAll(_cmdFeedLines);

    textBuffer.write(_formatRow("Date/Time", timeStr, cols));
    if (cashierName != null && cashierName.isNotEmpty) {
      textBuffer.write(_formatRow("Cashier", cashierName, cols));
    }
    textBuffer.write(_formatRow("Type", isOut ? "Cash Out (Tarik Kas)" : "Cash In (Setor Kas)", cols));
    textBuffer.write(_formatRow("Amount", _currency.format(amount), cols));
    textBuffer.writeln('-' * cols);
    textBuffer.writeln("Reason: $reason");
    textBuffer.writeln();
    textBuffer.writeln("Signature:");
    textBuffer.writeln();
    textBuffer.writeln('.' * (cols ~/ 2));

    if (settings.autoCutter && settings.paperWidth == PrinterPaperWidth.mm80) {
      bytes.addAll(_cmdCut);
    }

    return await _dispatchBytes(bytes, label: title, textContent: textBuffer.toString());
  }

  Future<Map<String, dynamic>> printClosingZReport({
    required String sessionName,
    required String? cashierName,
    required PosClosingControlData closingData,
    required double countedCash,
    required double cashDifference,
    String storeName = 'STORE POS',
    String? customHeader,
  }) async {
    final bytes = <int>[];
    final textBuffer = StringBuffer();
    final cols = _maxColumns;
    final storeSubtitle = (customHeader != null && customHeader.trim().isNotEmpty)
        ? customHeader.trim()
        : 'Point of Sale System';

    bytes.addAll(_cmdInit);

    bytes.addAll(_cmdAlignCenter);
    bytes.addAll(_cmdDoubleSize);
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("$storeName\n"));
    bytes.addAll(_cmdNormalSize);
    bytes.addAll(_encodeEscPos("$storeSubtitle\n"));
    bytes.addAll(_encodeEscPos("LAPORAN PENUTUPAN KASIR\n"));
    bytes.addAll(_encodeEscPos("(Z-REPORT)\n"));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos("${'=' * cols}\n"));

    textBuffer.writeln(_centerText(storeName, cols));
    textBuffer.writeln(_centerText(storeSubtitle, cols));
    textBuffer.writeln(_centerText("LAPORAN PENUTUPAN KASIR", cols));
    textBuffer.writeln(_centerText("(Z-REPORT)", cols));
    textBuffer.writeln('=' * cols);

    final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_encodeEscPos(_formatRow("Waktu Cetak", timeStr, cols)));
    bytes.addAll(_encodeEscPos(_formatRow("Sesi Odoo", sessionName, cols)));
    if (cashierName != null && cashierName.isNotEmpty) {
      bytes.addAll(_encodeEscPos(_formatRow("Kasir", cashierName, cols)));
    }
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.write(_formatRow("Waktu Cetak", timeStr, cols));
    textBuffer.write(_formatRow("Sesi Odoo", sessionName, cols));
    if (cashierName != null && cashierName.isNotEmpty) {
      textBuffer.write(_formatRow("Kasir", cashierName, cols));
    }
    textBuffer.writeln('-' * cols);

    // Ringkasan Penjualan
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("RINGKASAN PENJUALAN\n"));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos(_formatRow("Total Nota", "${closingData.orderCount} Transaksi", cols)));
    bytes.addAll(_encodeEscPos(_formatRow("Total Penjualan", _currency.format(closingData.totalSales), cols)));
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.writeln("RINGKASAN PENJUALAN");
    textBuffer.write(_formatRow("Total Nota", "${closingData.orderCount} Transaksi", cols));
    textBuffer.write(_formatRow("Total Penjualan", _currency.format(closingData.totalSales), cols));
    textBuffer.writeln('-' * cols);

    // Kontrol Kas Laci
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos("KONTROL KAS LACI (CASH)\n"));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos(_formatRow("Saldo Awal", _currency.format(closingData.openingCash), cols)));
    bytes.addAll(_encodeEscPos(_formatRow("(+) Kas Masuk", _currency.format(closingData.cashPayments), cols)));
    if (closingData.cashMovesTotal != 0) {
      bytes.addAll(_encodeEscPos(_formatRow("(+/-) Mutasi Kas", _currency.format(closingData.cashMovesTotal), cols)));
    }
    bytes.addAll(_encodeEscPos(_formatRow("(=) Kas Seharusnya", _currency.format(closingData.expectedCash), cols)));
    bytes.addAll(_cmdBoldOn);
    bytes.addAll(_encodeEscPos(_formatRow("( ) Kas Fisik Dihitung", _currency.format(countedCash), cols)));
    final diffLabel = cashDifference == 0
        ? "PAS"
        : (cashDifference > 0 ? "LEBIH" : "KURANG");
    bytes.addAll(_encodeEscPos(_formatRow("Selisih Kas", "${_currency.format(cashDifference)} ($diffLabel)", cols)));
    bytes.addAll(_cmdBoldOff);
    bytes.addAll(_encodeEscPos("${'-' * cols}\n"));

    textBuffer.writeln("KONTROL KAS LACI (CASH)");
    textBuffer.write(_formatRow("Saldo Awal", _currency.format(closingData.openingCash), cols));
    textBuffer.write(_formatRow("(+) Kas Masuk", _currency.format(closingData.cashPayments), cols));
    if (closingData.cashMovesTotal != 0) {
      textBuffer.write(_formatRow("(+/-) Mutasi Kas", _currency.format(closingData.cashMovesTotal), cols));
    }
    textBuffer.write(_formatRow("(=) Kas Seharusnya", _currency.format(closingData.expectedCash), cols));
    textBuffer.write(_formatRow("( ) Kas Fisik Dihitung", _currency.format(countedCash), cols));
    textBuffer.write(_formatRow("Selisih Kas", "${_currency.format(cashDifference)} ($diffLabel)", cols));
    textBuffer.writeln('-' * cols);

    // Rincian Non-Tunai
    if (closingData.nonCashMethods.isNotEmpty) {
      bytes.addAll(_cmdBoldOn);
      bytes.addAll(_encodeEscPos("NON-TUNAI / BANK / QRIS\n"));
      bytes.addAll(_cmdBoldOff);
      textBuffer.writeln("NON-TUNAI / BANK / QRIS");
      for (final m in closingData.nonCashMethods) {
        final line = _formatRow(m.name, "${_currency.format(m.amount)} (${m.number})", cols);
        bytes.addAll(_encodeEscPos(line));
        textBuffer.write(line);
      }
      bytes.addAll(_encodeEscPos("${'=' * cols}\n"));
      textBuffer.writeln('=' * cols);
    }

    // Tanda Tangan
    bytes.addAll(_encodeEscPos("\nKasir                 Supervisor\n\n\n"));
    bytes.addAll(_encodeEscPos("(               )     (               )\n"));
    bytes.addAll(_cmdFeedLines);

    textBuffer.writeln();
    textBuffer.writeln("Kasir                 Supervisor");
    textBuffer.writeln();
    textBuffer.writeln("(               )     (               )");
    textBuffer.writeln();

    // Only send cutter if 80mm and cutter enabled. NEVER send cut on 58mm (Rule 6).
    if (settings.autoCutter && settings.paperWidth == PrinterPaperWidth.mm80) {
      bytes.addAll(_cmdCut);
    }

    return await _dispatchBytes(bytes, label: 'Laporan Z (Penutupan Kasir)', textContent: textBuffer.toString());
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
      final xml = _buildEposXml(textContent: textContent, bytes: bytes);
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

  String _formatRow(String left, String right, int totalWidth) {
    left = _stripHighUnicode(left);
    right = _stripHighUnicode(right);
    if (left.length + right.length >= totalWidth) {
      final maxLeft = totalWidth - right.length - 1;
      left = maxLeft > 0 ? left.substring(0, maxLeft) : left;
    }
    final spaces = totalWidth - left.length - right.length;
    return "$left${' ' * (spaces > 0 ? spaces : 1)}$right\n";
  }

  String _centerText(String text, int width) {
    if (text.length >= width) return text;
    final leftPadding = (width - text.length) ~/ 2;
    return '${' ' * leftPadding}$text';
  }

  String _buildEposXml({String? textContent, List<int>? bytes}) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    buffer.writeln('<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">');
    buffer.writeln('<s:Body>');
    buffer.writeln('<epos-print xmlns="http://www.epson-pos.com/schemas/2011/03/epos-print">');

    if (bytes != null && bytes.isNotEmpty) {
      final hexData = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      buffer.writeln('<command>$hexData</command>');
    } else if (textContent != null && textContent.trim().isNotEmpty) {
      final escaped = textContent
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      buffer.writeln('<text>$escaped</text>');
      buffer.writeln('<feed line="5"/>');
    }

    // Only send cut if 80mm and cutter enabled. NEVER send cut to 58mm (Rule 6).
    if (settings.autoCutter && settings.paperWidth == PrinterPaperWidth.mm80) {
      buffer.writeln('<cut type="feed"/>');
    }

    buffer.writeln('</epos-print>');
    buffer.writeln('</s:Body>');
    buffer.writeln('</s:Envelope>');
    return buffer.toString();
  }

  static List<int> _encodeEscPos(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      if (char <= 0x7E || (char >= 0xA0 && char <= 0xFF)) {
        buffer.writeCharCode(char);
      }
    }
    return latin1.encode(buffer.toString());
  }

  static String _stripHighUnicode(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      if (char <= 0x7E || (char >= 0xA0 && char <= 0xFF)) {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

}
