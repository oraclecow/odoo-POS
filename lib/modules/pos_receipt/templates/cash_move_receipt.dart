import 'package:intl/intl.dart';
import '../../../core/hardware/esc_pos_builder.dart';
import '../receipt_config.dart';

class CashMoveReceiptTemplate {
  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static EscPosDocument build({
    required int cols,
    required bool autoCutter,
    required bool is80mm,
    required CashMoveReceiptConfig config,
    required String type, // 'in' or 'out'
    required int amount,
    required String reason,
    String? cashierName,
    String? storeNameOverride,
  }) {
    final doc = EscPosBuilder(cols: cols);
    final isOut = type == 'out';
    final title = isOut ? 'CASH OUT VOUCHER' : 'CASH IN VOUCHER';
    final headerTitle = (storeNameOverride != null && storeNameOverride.isNotEmpty)
        ? storeNameOverride
        : config.headerTitle;

    // 1. Header Block
    doc.centerLine(headerTitle, bold: true);
    if (config.subtitle.isNotEmpty) {
      doc.centerMultiline(config.subtitle);
    }
    if (config.showVoucherBanner) {
      doc.title("*** $title ***");
    }
    doc.divider();

    // 2. Metadata & Amount Block
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    doc.leftLine("Waktu   : $timeStr");
    doc.leftLine("Kasir   : ${cashierName ?? 'Staff'}");
    doc.leftLine("Tipe    : ${isOut ? 'KAS KELUAR (OUT)' : 'KAS MASUK (IN)'}", bold: true);
    doc.divider();

    doc.row("NOMINAL :", _currency.format(amount), bold: true);
    doc.leftLine("Alasan / Keterangan:");
    doc.leftLine(reason);
    doc.divider();

    // 3. Optional Signature / Footer Block
    if (config.showSignature) {
      doc.blankLine();
      doc.leftLine("Signature: _____________________");
    }
    if (config.footerNote.isNotEmpty) {
      doc.centerMultiline(config.footerNote);
    }

    return doc.build(autoCutter: autoCutter, is80mm: is80mm, trailingBlankLine: true);
  }
}
