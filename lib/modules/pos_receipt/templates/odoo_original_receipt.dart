import 'package:intl/intl.dart';
import '../../../core/hardware/esc_pos_builder.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../receipt_config.dart';

/// Standard Odoo 19 `OrderReceipt` layout renderer.
/// Activated when `receipt_config.json` sets `"use_odoo_original_format": true`.
class OdooOriginalReceiptTemplate {
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
    String storeName = 'ARAWALI',
  }) {
    final doc = EscPosBuilder(cols: cols);
    final meta = config.odooMeta;

    // 1. Company Header Block (Standard Odoo CompanyInfo)
    final companyTitle = meta.companyName.isNotEmpty ? meta.companyName : storeName;
    doc.title(companyTitle);

    if (meta.street.isNotEmpty) doc.centerLine(meta.street);
    if (meta.city.isNotEmpty) doc.centerLine(meta.city);
    if (meta.phone.isNotEmpty) doc.centerLine("Tel: ${meta.phone}");
    if (meta.vat.isNotEmpty) doc.centerLine("NPWP/VAT: ${meta.vat}");
    if (meta.email.isNotEmpty) doc.centerLine(meta.email);
    if (meta.website.isNotEmpty) doc.centerLine(meta.website);

    // 2. Odoo `pos.config.receipt_header`
    final headerText = (meta.isHeaderOrFooter && meta.receiptHeader.isNotEmpty)
        ? meta.receiptHeader
        : config.customerReceipt.subtitle;
    if (headerText.isNotEmpty) {
      doc.blankLine();
      doc.centerMultiline(headerText);
    }

    // 3. Cashier & Customer ("Served by ...")
    doc.divider();
    if (cashierName != null && cashierName.isNotEmpty) {
      doc.centerLine("Served by $cashierName");
    }
    if (customer != null) {
      doc.centerLine("Customer: ${customer.name}");
      if (customer.points > 0 && config.customerReceipt.showLoyaltyPoints) {
        doc.centerLine("Loyalty Points: ${customer.points.toInt()}");
      }
    }
    doc.divider();

    // 4. Order Lines
    for (final item in items) {
      final isReturn = item.quantity < 0;
      final prodTitle = isReturn ? '[REFUND] ${item.product.name}' : item.product.name;
      doc.leftLine(prodTitle);
      doc.row(
        "  ${item.quantity} x ${_currency.format(item.originalUnitPrice)}",
        _currency.format(item.lineTotal),
      );
      if (item.discountPercent != null && item.discountPercent! > 0) {
        doc.leftLine("  With a ${item.discountPercent!.toStringAsFixed(0)}% discount");
      }
      if (item.modifiers.summaryDescription != 'Normal (Default)' &&
          item.modifiers.summaryDescription.isNotEmpty) {
        doc.leftLine("  [${item.modifiers.summaryDescription}]");
      }
      if (item.note != null && item.note!.isNotEmpty) {
        doc.leftLine("  Note: ${item.note}");
      }
    }

    // 5. Discounts & Loyalty
    if (orderDiscount > 0 || pointsDiscount > 0) {
      doc.divider();
      if (orderDiscount > 0) {
        final discLabel = orderDiscountPercent > 0
            ? "Discount (${orderDiscountPercent.toStringAsFixed(0)}%)"
            : "Discount";
        doc.row(discLabel, "-${_currency.format(orderDiscount)}");
      }
      if (pointsDiscount > 0) {
        doc.row("Loyalty ($redeemedPoints Pts)", "-${_currency.format(pointsDiscount)}");
      }
    }

    // 6. Totals & Payment Lines (Odoo standard uppercase TOTAL / CHANGE)
    doc.divider();
    doc.row("TOTAL", _currency.format(totalAmount), bold: true);
    doc.blankLine();

    final displayTendered = tenderedAmount != 0 ? tenderedAmount : totalAmount;
    final payLabel = paymentMethod.isNotEmpty ? paymentMethod : "Cash";
    doc.row(payLabel, _currency.format(displayTendered));
    doc.row("CHANGE", _currency.format(changeAmount), bold: true);
    doc.divider();

    // 7. Odoo `pos.config.receipt_footer`
    final footerText = (meta.isHeaderOrFooter && meta.receiptFooter.isNotEmpty)
        ? meta.receiptFooter
        : config.customerReceipt.footer;
    if (footerText.isNotEmpty) {
      doc.centerMultiline(footerText);
      doc.blankLine();
    }

    // 8. Standard Odoo bottom timestamp & Order Reference
    doc.centerLine("Powered by Odoo");
    final orderRef = posReference?.isNotEmpty == true
        ? posReference!
        : (trackingNumber?.isNotEmpty == true ? "Order #$trackingNumber" : "Order #$orderNumber");
    doc.centerLine(orderRef);
    doc.centerLine(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()));

    return doc.build(autoCutter: autoCutter, is80mm: is80mm, trailingBlankLine: true);
  }
}
