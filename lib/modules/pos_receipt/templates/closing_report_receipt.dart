import 'package:intl/intl.dart';
import '../../../core/hardware/esc_pos_builder.dart';
import '../../../data/services/odoo_client.dart';
import '../receipt_config.dart';

class ClosingReportReceiptTemplate {
  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static EscPosDocument build({
    required int cols,
    required bool autoCutter,
    required bool is80mm,
    required SessionCloseReceiptConfig config,
    required String sessionName,
    required String? cashierName,
    required PosClosingControlData closingData,
    required double countedCash,
    required double cashDifference,
    String? storeNameOverride,
  }) {
    final doc = EscPosBuilder(cols: cols);
    final headerTitle = (storeNameOverride != null && storeNameOverride.isNotEmpty)
        ? storeNameOverride
        : config.headerTitle;

    // 1. Header Block
    doc.title(headerTitle);
    if (config.reportTitle.isNotEmpty) {
      doc.centerLine(config.reportTitle, bold: true);
    }
    if (config.subtitle.isNotEmpty) {
      doc.centerMultiline(config.subtitle);
    }
    doc.divider(config.headerDividerChar.isNotEmpty ? config.headerDividerChar : '=');

    // 2. Session Metadata Block
    final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    doc.leftLine("Sesi    : $sessionName");
    doc.leftLine("Waktu   : $timeStr");
    doc.leftLine("Kasir   : ${cashierName ?? 'Staff'}");
    doc.divider();

    // 3. Sales Summary Block
    doc.row("Total Transaksi", "${closingData.orderCount} Order");
    doc.row("Total Penjualan", _currency.format(closingData.totalSales), bold: true);
    doc.divider();

    // 4. Cash Drawer Reconciliation Block
    doc.leftLine("REKONSILIASI KAS LACI (TUNAI)", bold: true);
    doc.row("Modal Awal", _currency.format(closingData.openingCash));
    doc.row("+ Penjualan Tunai", _currency.format(closingData.cashPayments));
    doc.row("+/- Kas Masuk/Keluar", _currency.format(closingData.cashMovesTotal));

    // Detailed Cash In / Out lines if present and enabled
    if (config.showCashMovesDetail && closingData.cashMoves.isNotEmpty) {
      for (final m in closingData.cashMoves) {
        final name = (m['name']?.toString() ?? 'Move').trim();
        final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
        final shortName = name.length > 18 ? '${name.substring(0, 18)}..' : name;
        doc.row("  * $shortName", _currency.format(amt));
      }
    }

    doc.divider();
    doc.row("Kas Seharusnya", _currency.format(closingData.expectedCash), bold: true);
    doc.row("Fisik Kas Dihitung", _currency.format(countedCash), bold: true);

    final diffSign = cashDifference > 0 ? '+' : '';
    doc.row("Selisih Kas", "$diffSign${_currency.format(cashDifference)}", bold: true);

    // 5. Non-Cash Payment Breakdown Block
    if (config.showNonCashBreakdown && closingData.nonCashMethods.isNotEmpty) {
      doc.divider();
      doc.leftLine("PEMBAYARAN NON-TUNAI", bold: true);
      for (final pm in closingData.nonCashMethods) {
        doc.row(pm.name, _currency.format(pm.amount));
      }
    }

    doc.divider(config.headerDividerChar.isNotEmpty ? config.headerDividerChar : '=');

    // 6. Optional Signature / Footer Block
    if (config.showSignature) {
      doc.blankLine();
      doc.centerLine("Kasir                 Supervisor");
      doc.blankLine();
      doc.blankLine();
      doc.centerLine("(___________)      (___________)");
    }
    if (config.footerNote.isNotEmpty) {
      doc.centerMultiline(config.footerNote);
    }

    return doc.build(autoCutter: autoCutter, is80mm: is80mm, trailingBlankLine: true);
  }
}
