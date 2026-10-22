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
    final effectiveHeader = (storeNameOverride != null && storeNameOverride.trim().isNotEmpty)
        ? storeNameOverride.trim()
        : config.header;

    // 1. Header Block
    doc.title(effectiveHeader);
    if (config.showAddress && config.address.isNotEmpty) {
      doc.centerMultiline(config.address, bold: true);
    }
    if (config.title.isNotEmpty) {
      doc.centerLine(config.title, bold: true);
    }
    if (config.subtitle.isNotEmpty) {
      doc.centerLine(config.subtitle, bold: true);
    }
    doc.doubleDivider();

    // 2. Session Metadata Block
    final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    doc.row("Waktu Cetak", timeStr);
    doc.row("Sesi Odoo", sessionName);
    if (cashierName != null && cashierName.isNotEmpty) {
      doc.row("Kasir", cashierName);
    }
    doc.divider();

    // 3. Sales Summary Block
    if (config.showSalesSummary) {
      doc.leftLine("RINGKASAN PENJUALAN", bold: true);
      doc.row("Total Nota", "${closingData.orderCount} Transaksi");
      doc.row("Total Penjualan", _currency.format(closingData.totalSales));
      doc.divider();
    }

    // 4. Cash Drawer Control Block
    if (config.showCashControl) {
      doc.leftLine("KONTROL KAS LACI (CASH)", bold: true);
      doc.row("Saldo Awal", _currency.format(closingData.openingCash));
      doc.row("(+) Kas Masuk", _currency.format(closingData.cashPayments));
      if (closingData.cashMovesTotal != 0) {
        doc.row("(+/-) Mutasi Kas", _currency.format(closingData.cashMovesTotal));
      }
      doc.row("(=) Kas Seharusnya", _currency.format(closingData.expectedCash));
      doc.row("( ) Kas Fisik Dihitung", _currency.format(countedCash), bold: true);
      final diffLabel = cashDifference == 0
          ? "PAS"
          : (cashDifference > 0 ? "LEBIH" : "KURANG");
      doc.row("Selisih Kas", "${_currency.format(cashDifference)} ($diffLabel)", bold: true);
      doc.divider();
    }

    // 5. Non-Cash / QRIS Block
    if (config.showNonCashQris && closingData.nonCashMethods.isNotEmpty) {
      doc.leftLine("NON-TUNAI / BANK / QRIS", bold: true);
      for (final m in closingData.nonCashMethods) {
        doc.row(m.name, "${_currency.format(m.amount)} (${m.number})");
      }
      doc.doubleDivider();
    } else {
      doc.doubleDivider();
    }

    // 6. Optional Signature / Footer Block (disabled by default per config)
    if (config.showSignature) {
      doc.blankLine();
      doc.leftLine("Kasir                 Supervisor");
      doc.blankLine();
      doc.leftLine("(               )     (               )");
    }
    if (config.footer.isNotEmpty) {
      doc.centerMultiline(config.footer);
    }

    return doc.build(autoCutter: autoCutter, is80mm: is80mm);
  }
}
