import 'package:intl/intl.dart';
import '../../../core/hardware/esc_pos_builder.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/services/odoo_client.dart';
import '../receipt_config.dart';
import 'odoo_original_receipt.dart';

class CustomerReceiptTemplate {
  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static EscPosDocument buildCustomerReceipt({
    required int cols,
    required bool autoCutter,
    required bool is80mm,
    required ReceiptConfig config,
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
    String storeName = 'MAIN STORE POS',
    String? customHeader,
    String? customFooter,
    int companyId = 1,
  }) {
    if (config.useOdooOriginalFormat) {
      return OdooOriginalReceiptTemplate.buildCustomerReceipt(
        cols: cols,
        autoCutter: autoCutter,
        is80mm: is80mm,
        config: config,
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
      );
    }

    final doc = EscPosBuilder(cols: cols);
    final cfg = config.customerReceipt;
    final meta = config.odooMeta;

    final cleanStoreName = storeName.isNotEmpty ? storeName : cfg.storeName;
    final storeSubtitle = (config.syncHeaderFooterFromOdoo && meta.receiptHeader.isNotEmpty)
        ? meta.receiptHeader
        : ((customHeader != null && customHeader.isNotEmpty) ? customHeader : cfg.subtitle);
    final receiptFooter = (config.syncHeaderFooterFromOdoo && meta.receiptFooter.isNotEmpty)
        ? meta.receiptFooter
        : ((customFooter != null && customFooter.isNotEmpty) ? customFooter : cfg.footer);

    // 1. Header Block
    doc.title(cleanStoreName);
    if (cfg.showSubtitle && storeSubtitle.isNotEmpty) {
      doc.centerMultiline(storeSubtitle);
    }
    doc.blankLine();

    // 2. Metadata Block
    final dateStr = DateFormat('dd/MM/yy HH:mm').format(DateTime.now());
    final effectiveCashier = cashierName?.isNotEmpty == true ? cashierName! : 'Kasir';
    final customerDisplay = customer != null
        ? '${customer.name}${customer.points > 0 && cfg.showLoyaltyPoints ? " (${customer.points.toInt()} Poin)" : ""}'
        : 'Umum';
    final orderDisplay = posReference?.isNotEmpty == true
        ? posReference!
        : (trackingNumber?.isNotEmpty == true ? "#$trackingNumber (Order #$orderNumber)" : "Order #$orderNumber");
    final cleanOrderLabel = orderDisplay.toLowerCase().startsWith('order') ? orderDisplay : "Order $orderDisplay";

    if (cfg.showCashier) {
      doc.leftLine("$dateStr : $effectiveCashier");
    } else {
      doc.leftLine(dateStr);
    }
    if (cfg.showCustomer) {
      doc.leftLine("Pelanggan : $customerDisplay");
    }
    doc.leftLine(cleanOrderLabel);
    doc.divider();

    // 3. Item Lines Block
    for (final item in items) {
      final isReturn = item.quantity < 0;
      final prodTitle = isReturn ? '[RETUR] ${item.product.name}' : item.product.name;
      doc.leftLine(prodTitle);
      doc.row(
        "  ${item.quantity} X ${_currency.format(item.unitPrice)}",
        _currency.format(item.lineTotal),
      );

      if (item.discountPercent != null && item.discountPercent! > 0) {
        doc.leftLine("  (Disc ${item.discountPercent!.toStringAsFixed(0)}%)");
      }
      if (item.modifiers.summaryDescription != 'Normal (Default)' &&
          item.modifiers.summaryDescription.isNotEmpty) {
        doc.leftLine("  [${item.modifiers.summaryDescription}]");
      }
      if (item.note != null && item.note!.isNotEmpty) {
        doc.leftLine("  Catatan: ${item.note}");
      }
    }

    // 4. Discounts & Loyalty Redemptions Block
    if (orderDiscount > 0 || pointsDiscount > 0) {
      doc.divider();
      if (orderDiscount > 0) {
        final discLabel = orderDiscountPercent > 0
            ? "Diskon (${orderDiscountPercent.toStringAsFixed(0)}%)"
            : "Diskon Cart";
        doc.row(discLabel, "-${_currency.format(orderDiscount)}");
      }
      if (pointsDiscount > 0) {
        doc.row("Tukar $redeemedPoints Pts", "-${_currency.format(pointsDiscount)}");
      }
    }

    doc.divider();

    // 5. Totals & Payment Block
    doc.row("Grand Total", _currency.format(totalAmount), bold: true);

    final displayTendered = tenderedAmount != 0 ? tenderedAmount : totalAmount;
    final payMethodLabel = paymentMethod.isNotEmpty && paymentMethod.toLowerCase() != 'bayar'
        ? "Bayar ($paymentMethod)"
        : "Bayar";
    doc.row(payMethodLabel, _currency.format(displayTendered));

    if (changeAmount != 0) {
      doc.row("Kembali", _currency.format(changeAmount));
    }

    doc.divider();

    // 6. Footer Block
    if (cfg.showFooter && receiptFooter.isNotEmpty) {
      doc.centerMultiline(receiptFooter);
    }

    return doc.build(autoCutter: autoCutter, is80mm: is80mm, trailingBlankLine: true);
  }

  static EscPosDocument buildHistoryReceipt({
    required int cols,
    required bool autoCutter,
    required bool is80mm,
    required ReceiptConfig config,
    required OdooOrderRecord order,
    List<Map<String, dynamic>>? lines,
    String storeName = 'MAIN STORE POS',
    String? customHeader,
    String? customFooter,
    int companyId = 1,
  }) {
    final doc = EscPosBuilder(cols: cols);
    final cfg = config.customerReceipt;
    final meta = config.odooMeta;

    final cleanStoreName = storeName.isNotEmpty ? storeName : cfg.storeName;
    final storeSubtitle = (config.syncHeaderFooterFromOdoo && meta.receiptHeader.isNotEmpty)
        ? meta.receiptHeader
        : ((customHeader != null && customHeader.isNotEmpty) ? customHeader : cfg.subtitle);
    final receiptFooter = (config.syncHeaderFooterFromOdoo && meta.receiptFooter.isNotEmpty)
        ? meta.receiptFooter
        : ((customFooter != null && customFooter.isNotEmpty) ? customFooter : cfg.footer);

    // Header
    doc.title(cleanStoreName);
    if (cfg.showSubtitle && storeSubtitle.isNotEmpty) {
      doc.centerMultiline(storeSubtitle);
    }
    doc.centerLine("DUPLIKAT STRUK (REPRINT)");
    doc.divider();

    // Meta details
    doc.leftLine(order.localDateOrder);
    doc.leftLine("Pelanggan : ${order.partnerName}");
    doc.leftLine("Order ${order.posReference.isNotEmpty ? order.posReference : order.name}");
    doc.divider();

    // Lines
    if (lines != null && lines.isNotEmpty) {
      for (final l in lines) {
        String prodName = 'Item';
        final fpn = l['full_product_name'];
        if (fpn is String && fpn.trim().isNotEmpty && fpn.trim().toLowerCase() != 'false') {
          prodName = fpn.trim();
        } else if (l['product_id'] is List &&
            (l['product_id'] as List).length > 1 &&
            (l['product_id'] as List)[1] != null) {
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
        doc.leftLine(title);

        final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
        doc.row("  $qtyStr X ${_currency.format(unitPrice)}", _currency.format(subtotal));
      }
      doc.divider();
    }

    // Totals
    doc.row("Grand Total", _currency.format(order.amountTotal), bold: true);
    doc.row("Status", order.state.toUpperCase());
    doc.divider();

    // Footer
    if (cfg.showFooter && receiptFooter.isNotEmpty) {
      doc.centerMultiline(receiptFooter);
    }
    doc.centerLine("Cetak Ulang Arsip Kasir");

    return doc.build(autoCutter: autoCutter, is80mm: is80mm, trailingBlankLine: true);
  }
}
