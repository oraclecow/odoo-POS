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
  }) {
    final doc = EscPosBuilder(cols: cols);
    final isOut = type == 'out';
    final title = isOut ? 'CASH OUT VOUCHER' : 'CASH IN VOUCHER';

    // 1. Optional Banner (disabled by default per config)
    if (config.showVoucherBanner) {
      doc.title("*** $title ***");
    }

    // 2. Store Header
    if (config.header.isNotEmpty) {
      doc.centerMultiline(config.header, bold: true);
    }
    doc.doubleDivider();

    // 3. Body Rows
    final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    doc.row("Date/Time", timeStr);
    if (config.showCashier && cashierName != null && cashierName.isNotEmpty) {
      doc.row("Cashier", cashierName);
    }
    doc.row("Type", isOut ? "Cash Out (Tarik Kas)" : "Cash In (Setor Kas)");
    doc.row("Amount", _currency.format(amount), bold: true);
    doc.divider();

    if (config.showReason) {
      doc.leftLine("Reason: $reason");
    }

    // 4. Optional Signature Block (disabled by default per config)
    if (config.showSignature) {
      doc.blankLine();
      doc.leftLine("Signature:");
      doc.blankLine();
      doc.leftLine('.' * (cols ~/ 2));
    }

    // 5. Optional Footer
    if (config.footer.isNotEmpty) {
      doc.divider();
      doc.centerMultiline(config.footer);
    }

    return doc.build(autoCutter: autoCutter, is80mm: is80mm);
  }
}
