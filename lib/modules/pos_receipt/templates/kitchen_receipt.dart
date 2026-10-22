import 'package:intl/intl.dart';
import '../../../core/hardware/esc_pos_builder.dart';
import '../../../data/models/order.dart';
import '../receipt_config.dart';

class KitchenReceiptTemplate {
  static EscPosDocument build({
    required int cols,
    required bool autoCutter,
    required bool is80mm,
    required KitchenReceiptConfig config,
    required int orderNumber,
    required List<CartItem> items,
    required String channelName,
    String? posReference,
    String? trackingNumber,
    String? note,
    String? cashierName,
  }) {
    final doc = EscPosBuilder(cols: cols);

    doc.title(config.headerTitle);
    doc.centerLine("CHANNEL: $channelName", bold: true);
    doc.doubleDivider();

    final ticketNum = trackingNumber != null && trackingNumber.isNotEmpty
        ? "#$trackingNumber ($orderNumber)"
        : "#$orderNumber";
    final refStr = posReference != null && posReference.isNotEmpty ? " | $posReference" : "";
    final orderMeta = "Order: $ticketNum$refStr | ${DateFormat('HH:mm:ss').format(DateTime.now())}";
    doc.leftLine(orderMeta);

    if (cashierName != null && cashierName.isNotEmpty) {
      doc.leftLine("Cashier: $cashierName");
    }

    if (config.showNotes && note != null && note.isNotEmpty) {
      doc.leftLine("Note: $note", bold: true);
    }
    doc.divider();

    for (final item in items) {
      doc.leftLine("${item.quantity}x ${item.product.name}", bold: true, doubleSize: true);
      if (item.modifiers.summaryDescription != 'Normal (Default)' &&
          item.modifiers.summaryDescription.isNotEmpty) {
        doc.leftLine("   -> ${item.modifiers.summaryDescription}");
      }
      doc.blankLine();
    }

    doc.doubleDivider();
    return doc.build(autoCutter: autoCutter, is80mm: is80mm, trailingBlankLine: true);
  }
}
