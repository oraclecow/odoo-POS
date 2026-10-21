import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';
import 'customer_keypad_dialog.dart';
import 'order_note_dialog.dart';
import 'cashier_action_menu.dart';
import 'payment_dialog.dart';
import 'cart_item_adjust_dialog.dart';
import 'cart_item_quantity_dialog.dart';
import 'cashier_select_dialog.dart';
import 'open_session_dialog.dart';
import 'order_tabs_bar.dart';
import '../../data/services/printer/printer_service.dart';
import '../../data/models/order.dart';

class OrderTicketPanel extends ConsumerWidget {
  const OrderTicketPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(posControllerProvider);
    final repo = ref.watch(juicePosRepositoryProvider);
    final odooClient = ref.watch(odooClientProvider);
    final printerService = ref.watch(printerServiceProvider);
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      color: AppColors.ticketBackground,
      child: Column(
        children: [
          // 1. Consolidated Top Header: [Register | Orders] + Odoo Status Badge + [⋮ Menu]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: const BoxDecoration(
              color: AppColors.cyanTopbar,
              border: Border(bottom: BorderSide(color: AppColors.borderDark, width: 2)),
            ),
            child: Row(
              children: [
                // Register / Orders Segmented Tabs
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.deepSlate,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDark, width: 1.5),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => controller.setActiveTab('Register'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: controller.activeTab == 'Register' ? AppColors.sunYellow : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: controller.activeTab == 'Register'
                                    ? [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))]
                                    : null,
                              ),
                              child: Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: controller.activeTab == 'Register' ? AppColors.pitchBlack : AppColors.pureWhite,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => controller.setActiveTab('Orders'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: controller.activeTab == 'Orders' ? AppColors.sunYellow : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: controller.activeTab == 'Orders'
                                    ? [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))]
                                    : null,
                              ),
                              child: Text(
                                'Orders',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: controller.activeTab == 'Orders' ? AppColors.pitchBlack : AppColors.pureWhite,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Odoo Session Indicator Badge
                InkWell(
                  onTap: () {
                    OpenSessionDialog.show(context, controller);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.deepSlate,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.borderDark,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          controller.isSessionOpen ? Icons.cloud_done_rounded : Icons.lock_clock_rounded,
                          size: 15,
                          color: controller.isSessionOpen ? AppColors.sunYellow : Colors.amber.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.isSessionOpen
                              ? '#${controller.activeSessionId}'
                              : 'Open Session',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: controller.isSessionOpen ? AppColors.sunYellow : Colors.amber.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 3-Dots Cashier Actions Menu Button (Contains Printer & App Settings)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.pitchBlack),
                  tooltip: 'Cashier Actions',
                  onPressed: () => CashierActionMenu.show(context, odooClient, controller, printerService),
                ),
              ],
            ),
          ),

          // 1.5. Floating Orders (Multiple Carts Tab Bar - Odoo 19 Native Workflow)
          const OrderTabsBar(),

          // 2. Order Metadata, Active Cashier Chip & Channel Selector Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: const BoxDecoration(
              color: AppColors.deepSlate,
              border: Border(bottom: BorderSide(color: AppColors.borderDark, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Order #${controller.orderNumber}',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      // Active Cashier Chip
                      InkWell(
                        onTap: () => CashierSelectDialog.show(context, controller),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cartRow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cartRowBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_rounded, size: 14, color: AppColors.sunYellow),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  controller.activeCashier?.name ?? 'Select Cashier',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Member / Pelanggan Pill (Replaces Restaurant Order Channel)
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => CustomerKeypadDialog(
                        repository: repo,
                        posController: controller,
                        currentCustomer: controller.customer,
                        onClearCustomer: () => controller.setCustomer(null),
                        onCustomerSelected: (cust) => controller.setCustomer(cust),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: controller.customer != null ? AppColors.sunYellow : AppColors.cartRow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.customer != null ? AppColors.borderDark : AppColors.cartRowBorder,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_membership_rounded,
                          size: 15,
                          color: controller.customer != null ? AppColors.pitchBlack : AppColors.sunYellow,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          controller.customer != null
                              ? '${controller.customer!.name} (${controller.customer!.pointsDisplay} pts)'
                              : '+ Member',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: controller.customer != null ? AppColors.pitchBlack : Colors.white,
                          ),
                        ),
                        if (controller.customer != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => controller.setCustomer(null),
                            child: const Icon(Icons.cancel_rounded, size: 14, color: AppColors.pitchBlack),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Scrollable Cart Items List with Watermark Background
          Expanded(
            child: Stack(
              children: [
                // Watermark Brand Logo in Cart Background
                Center(
                  child: Opacity(
                    opacity: 0.12,
                    child: Image.asset(
                      'assets/images/store_logo.png',
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                controller.cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_basket_outlined, size: 48, color: Color(0xFF475569)),
                            const SizedBox(height: 8),
                            const Text(
                              'Belum ada item dipilih',
                              style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Scan barcode atau pilih produk di katalog',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        itemCount: controller.cartItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = controller.cartItems[index];
                          final isReturn = item.quantity < 0;
                          final hasDiscount = item.discountPercent != null && item.discountPercent! > 0;

                          return InkWell(
                            onTap: isReturn
                                ? null
                                : () => CartItemAdjustDialog.show(
                                      context,
                                      item: item,
                                      controller: controller,
                                    ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isReturn ? const Color(0xFF2E1212) : AppColors.cartRow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isReturn
                                      ? Colors.redAccent.shade400
                                      : (hasDiscount ? AppColors.brandOrange.withOpacity(0.7) : AppColors.cartRowBorder),
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product details, modifiers & discounts
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isReturn) ...[
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade700,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'RETUR',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                            ],
                                            Expanded(
                                              child: Text(
                                                item.product.name,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isReturn ? Colors.red.shade200 : AppColors.pureWhite,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.modifiers.summaryDescription.isNotEmpty &&
                                            item.modifiers.summaryDescription != 'Normal (Default)') ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.modifiers.summaryDescription,
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.brandOrange, fontWeight: FontWeight.w700, height: 1.2),
                                          ),
                                        ],
                                        if (item.note != null && item.note!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '📝 ${item.note}',
                                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.sunYellow),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (hasDiscount) ...[
                                              Text(
                                                currency.format(item.originalUnitPrice * item.quantity),
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  decoration: TextDecoration.lineThrough,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Text(
                                              currency.format(item.lineTotal),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: isReturn
                                                    ? Colors.redAccent.shade100
                                                    : (hasDiscount ? AppColors.brandOrange : AppColors.sunYellow),
                                              ),
                                            ),
                                            if (hasDiscount) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.brandOrange.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppColors.brandOrange, width: 1),
                                                ),
                                                child: Text(
                                                  '-${item.discountPercent!.toStringAsFixed(0)}%',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.brandOrange,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stepper or Delete for return items
                                  if (isReturn) ...[
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Colors.redAccent),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Batalkan item retur',
                                      onPressed: () => controller.removeItem(item.lineId),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.redAccent),
                                      ),
                                    ),
                                  ] else ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: Color(0xFF94A3B8)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => controller.updateQuantity(item.lineId, -1),
                                        ),
                                        // Direct Numpad Quantity Input Chip
                                        InkWell(
                                          onTap: () async {
                                            final newQty = await CartItemQuantityDialog.show(
                                              context,
                                              productName: item.product.name,
                                              unitPrice: item.unitPrice,
                                              initialQuantity: item.quantity,
                                              sku: item.product.defaultCode,
                                            );
                                            if (newQty != null) {
                                              controller.setLineQuantity(item.lineId, newQty);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Tooltip(
                                            message: 'Ubah jumlah (Numpad)',
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                                              ),
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: AppColors.sunYellow),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => controller.updateQuantity(item.lineId, 1),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),

          // 4. Bottom Controls: Single Row [Member / Pelanggan] + [Note]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: const BoxDecoration(
              color: AppColors.deepSlate,
              border: Border(top: BorderSide(color: AppColors.borderDark, width: 2)),
            ),
            child: Row(
              children: [
                // Member Button (Opens CustomerKeypadDialog with Search & Point Exchange Tabs)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => CustomerKeypadDialog(
                          repository: repo,
                          posController: controller,
                          currentCustomer: controller.customer,
                          onClearCustomer: () => controller.setCustomer(null),
                          onCustomerSelected: (cust) => controller.setCustomer(cust),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      side: const BorderSide(color: AppColors.borderDark, width: 1.5),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 15,
                          color: AppColors.borderDark,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            controller.customer != null
                                ? '${controller.customer!.name} (${controller.customer!.pointsDisplay} pts)'
                                : '[Member / Pelanggan]',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.borderDark,
                            ),
                          ),
                        ),
                        if (controller.customer != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => controller.setCustomer(null),
                            child: const Icon(Icons.cancel_rounded, size: 14, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Note Button (Opens Order Note Dialog)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => OrderNoteDialog(
                          initialNote: controller.orderNote,
                          onSave: (note) => controller.setOrderNote(note),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      side: const BorderSide(color: AppColors.borderDark, width: 1.5),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.note_alt_outlined,
                          size: 15,
                          color: AppColors.borderDark,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            controller.orderNote != null ? '📝 Catatan' : '[Note]',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.borderDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Totals & Pay Button (Opens PaymentDialog)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            decoration: const BoxDecoration(
              color: AppColors.deepSlate,
              border: Border(top: BorderSide(color: AppColors.cartRowBorder, width: 1.5)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFCBD5E1))),
                    Text(currency.format(controller.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
                if (controller.totalLineDiscounts > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hemat Diskon Item:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.brandOrange),
                      ),
                      Text(
                        '-${currency.format(controller.totalLineDiscounts)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brandOrange),
                      ),
                    ],
                  ),
                ],
                if (controller.orderDiscountTotal > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Diskon ${controller.orderDiscountPercent > 0 ? '(${controller.orderDiscountPercent.toStringAsFixed(0)}%)' : ''}:',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.brandOrange),
                      ),
                      Text(
                        '-${currency.format(controller.orderDiscountTotal)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brandOrange),
                      ),
                    ],
                  ),
                ],
                if (controller.pointsDiscount > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tukar Poin (${controller.redeemedPoints} pts):',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.sunYellow),
                      ),
                      Text(
                        '-${currency.format(controller.pointsDiscount)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.sunYellow),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      controller.total < 0 ? 'Total Refund:' : 'Total:',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: controller.total < 0 ? Colors.redAccent.shade100 : Colors.white,
                      ),
                    ),
                    Text(
                      currency.format(controller.total),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: controller.total < 0 ? Colors.redAccent.shade100 : AppColors.sunYellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: controller.cartItems.isEmpty
                        ? null
                        : () async {
                            // Ensure an active session is open in Odoo 19 before checkout
                            if (!controller.isSessionOpen) {
                              final opened = await OpenSessionDialog.show(context, controller);
                              if (opened != true || !context.mounted) return;
                            }

                            final savedDiscountAmt = controller.orderDiscountAmount;
                            final savedDiscountPct = controller.orderDiscountPercent;
                            final savedRedeemedPts = controller.redeemedPoints;
                            final savedPointsDisc = controller.pointsDiscount;

                            final paymentResult = await showDialog<PaymentResult>(
                              context: context,
                              builder: (ctx) => PaymentDialog(
                                totalAmount: controller.total,
                                onConfirmPayment: ({
                                  required String paymentMethod,
                                  required int tenderedAmount,
                                  required int changeAmount,
                                }) async {
                                  // Send directly to Odoo 19 via sync_from_ui with active cashier and cart UUID
                                  return await odooClient.submitPosOrder(
                                    items: controller.cartItems,
                                    totalAmount: controller.total,
                                    paidAmount: tenderedAmount,
                                    changeAmount: changeAmount,
                                    paymentMethodName: paymentMethod,
                                    orderDiscountAmount: savedDiscountAmt,
                                    orderDiscountPercent: savedDiscountPct,
                                    pointsDiscount: savedPointsDisc,
                                    redeemedPoints: savedRedeemedPts,
                                    orderUuid: controller.currentOrderUuid,
                                    partnerId: controller.customer?.id,
                                    orderNote: controller.orderNote,
                                    channelTag: controller.channel.displayName,
                                    cashier: controller.activeCashier,
                                  );
                                },
                              ),
                            );

                            if (paymentResult != null && context.mounted) {
                              final completedItems = List<CartItem>.from(controller.cartItems);
                              final completedTotal = controller.total;
                              final completedCustomer = controller.customer;
                              final savedOrderNum = controller.orderNumber;
                              final cashierName = controller.activeCashier?.name ?? 'Staff';
                              final finalMethod = paymentResult.paymentMethod;
                              final finalTendered = paymentResult.tenderedAmount;
                              final finalChange = paymentResult.changeAmount;
                              final trackingNumber = paymentResult.submissionResult?.trackingNumber;
                              final posReference = paymentResult.submissionResult?.posReference;

                              // 1. CLEAR CART IMMEDIATELY - transaction is already committed to Odoo!
                              controller.clearCart();

                              final ticketLabel = trackingNumber != null && trackingNumber.isNotEmpty
                                  ? 'No. Antrian: #$trackingNumber (${posReference ?? 'Order #$savedOrderNum'})'
                                  : 'Order #$savedOrderNum';

                              // 2. SHOW SUCCESS DIALOG IMMEDIATELY
                              showDialog(
                                context: context,
                                builder: (sCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  title: Row(
                                    children: [
                                      Image.asset('assets/images/store_logo.png', height: 38, fit: BoxFit.contain),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(completedTotal < 0 ? 'Refund Successful!' : 'Order Successful!',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          const Text('OPEN ODOO POS', style: TextStyle(fontSize: 11, color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$ticketLabel berhasil disinkronkan ke Odoo 19 POS oleh $cashierName.',
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.print_rounded, size: 16, color: AppColors.primaryRed),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                printerService.settings.autoPrintReceipt
                                                    ? 'Mencetak struk kasir...'
                                                    : 'Auto-print non-aktif.',
                                                style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.print_rounded, size: 16),
                                      label: const Text('Struk Kasir'),
                                      onPressed: () async {
                                        final res = await printerService.printCustomerReceipt(
                                          orderNumber: savedOrderNum,
                                          posReference: posReference,
                                          trackingNumber: trackingNumber,
                                          items: completedItems,
                                          totalAmount: completedTotal,
                                          paymentMethod: finalMethod,
                                          tenderedAmount: finalTendered,
                                          changeAmount: finalChange,
                                          orderDiscount: savedDiscountAmt,
                                          orderDiscountPercent: savedDiscountPct,
                                          pointsDiscount: savedPointsDisc,
                                          redeemedPoints: savedRedeemedPts,
                                          customer: completedCustomer,
                                          cashierName: cashierName,
                                          storeName: odooClient.profile.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
                                          companyId: odooClient.profile.companyId,
                                          customHeader: odooClient.profile.receiptHeader,
                                          customFooter: odooClient.profile.receiptFooter,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(res['message'] ?? 'Print command sent.'),
                                              backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                                      label: const Text('Buka Laci'),
                                      onPressed: () async {
                                        final res = await printerService.kickCashDrawer();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(res['message'] ?? 'Laci kasir dibuka.'),
                                              backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(sCtx),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                                      child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );

                              // 3. ASYNCHRONOUS AUTO-PRINT & CASH DRAWER KICK
                              Future.microtask(() async {
                                try {
                                  // Auto kick drawer on cash payments
                                  if (finalMethod.toLowerCase().contains('cash') || finalMethod.toLowerCase().contains('tunai')) {
                                    await printerService.kickCashDrawer();
                                  }

                                  if (printerService.settings.autoPrintReceipt) {
                                    await printerService.printCustomerReceipt(
                                      orderNumber: savedOrderNum,
                                      posReference: posReference,
                                      trackingNumber: trackingNumber,
                                      items: completedItems,
                                      totalAmount: completedTotal,
                                      paymentMethod: finalMethod,
                                      tenderedAmount: finalTendered,
                                      changeAmount: finalChange,
                                      orderDiscount: savedDiscountAmt,
                                      orderDiscountPercent: savedDiscountPct,
                                      pointsDiscount: savedPointsDisc,
                                      redeemedPoints: savedRedeemedPts,
                                      customer: completedCustomer,
                                      cashierName: cashierName,
                                      storeName: odooClient.profile.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
                                      companyId: odooClient.profile.companyId,
                                      customHeader: odooClient.profile.receiptHeader,
                                      customFooter: odooClient.profile.receiptFooter,
                                    );
                                  }
                                } catch (printErr) {
                                  debugPrint('[POS AutoPrint Error] $printErr');
                                }
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.total < 0 ? Colors.redAccent.shade700 : AppColors.sunYellow,
                      foregroundColor: controller.total < 0 ? Colors.white : AppColors.pitchBlack,
                      disabledBackgroundColor: const Color(0xFF334155),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderDark, width: 2.5),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      controller.total < 0
                          ? 'Refund ${currency.format(controller.total)} ➔'
                          : 'Pay ${currency.format(controller.total)} ➔',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: controller.total < 0 ? Colors.white : AppColors.pitchBlack,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
