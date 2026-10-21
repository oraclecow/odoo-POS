import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/floating_order.dart';
import '../core/app_colors.dart';

/// Odoo 19-inspired Order Tabs Bar for managing multiple concurrent carts (Floating Orders).
class OrderTabsBar extends ConsumerWidget {
  const OrderTabsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(posControllerProvider);
    final orders = controller.floatingOrders;
    final activeIndex = controller.activeOrderIndex;
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      height: 42,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate base
        border: Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // Scrollable Orders Tabs list
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final order = orders[index];
                final isActive = index == activeIndex;
                final qty = order.totalQuantity;

                return _buildOrderTab(
                  context: context,
                  order: order,
                  index: index,
                  isActive: isActive,
                  totalQuantity: qty,
                  currency: currency,
                  canClose: orders.length > 1,
                  onSelect: () => controller.selectFloatingOrder(index),
                  onClose: () => _confirmCloseOrder(context, controller, order, index, currency),
                );
              },
            ),
          ),
          const SizedBox(width: 6),

          // "+" Button to Park current order and open New Floating Order
          Tooltip(
            message: 'Buka Pesanan Baru / Parkir (Floating Order)',
            child: InkWell(
              onTap: () => controller.newFloatingOrder(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.sunYellow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderDark, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: AppColors.pitchBlack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTab({
    required BuildContext context,
    required PosFloatingOrder order,
    required int index,
    required bool isActive,
    required int totalQuantity,
    required NumberFormat currency,
    required bool canClose,
    required VoidCallback onSelect,
    required VoidCallback onClose,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          left: 10,
          right: (isActive && canClose) ? 4 : 10,
          top: 4,
          bottom: 4,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.sunYellow : AppColors.cartRow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.pitchBlack : AppColors.cartRowBorder,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [const BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order Label (e.g. "Order #1" or "#1 Budi")
            Text(
              order.tabLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppColors.pitchBlack : Colors.white70,
              ),
            ),

            // Item count badge
            if (totalQuantity > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.pitchBlack : Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalQuantity',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.sunYellow : Colors.white,
                  ),
                ),
              ),
            ],

            // Close button (only shown on active tab when multiple tabs exist)
            if (isActive && canClose) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black12,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.pitchBlack,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCloseOrder(
    BuildContext context,
    PosController controller,
    PosFloatingOrder order,
    int index,
    NumberFormat currency,
  ) async {
    // If order has items, prompt for confirmation to prevent accidental loss
    if (order.items.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text('Hapus Order #${order.orderNumber}?'),
            ],
          ),
          content: Text(
            'Pesanan ini berisi ${order.totalQuantity} barang (${currency.format(order.total)}).\n\nYakin ingin membatalkan dan menghapus pesanan ini?',
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus Pesanan'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    controller.removeFloatingOrder(index);
  }
}
