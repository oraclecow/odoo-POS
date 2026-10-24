import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/delivery_order.dart';
import '../../data/services/delivery/delivery_order_service.dart';
import '../../data/services/odoo_client.dart';
import '../../data/services/printer/printer_service.dart';

class IncomingDeliveryDialog extends StatefulWidget {
  final IncomingDeliveryOrder order;
  final DeliveryOrderService deliveryService;
  final OdooClient odooClient;
  final PrinterService printerService;
  final String? cashierName;

  const IncomingDeliveryDialog({
    super.key,
    required this.order,
    required this.deliveryService,
    required this.odooClient,
    required this.printerService,
    this.cashierName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required IncomingDeliveryOrder order,
    required DeliveryOrderService deliveryService,
    required OdooClient odooClient,
    required PrinterService printerService,
    String? cashierName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingDeliveryDialog(
        order: order,
        deliveryService: deliveryService,
        odooClient: odooClient,
        printerService: printerService,
        cashierName: cashierName,
      ),
    );
  }

  @override
  State<IncomingDeliveryDialog> createState() => _IncomingDeliveryDialogState();
}

class _IncomingDeliveryDialogState extends State<IncomingDeliveryDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isProcessing = false;

  bool get _isGrab => widget.order.channelLabel.toLowerCase().contains('grab');

  Color get _brandColor => _isGrab ? const Color(0xFF00B14F) : const Color(0xFFEE4D2D);
  IconData get _brandIcon => _isGrab ? Icons.electric_moped : Icons.shopping_bag;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: _brandColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_brandIcon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PESANAN BARU ${widget.order.channelLabel.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Order ID: #${widget.order.orderId}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.order.source == 'wifi_http' ? 'Store Wi-Fi' : 'On-Device',
                      style: TextStyle(
                        color: _brandColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Customer & Notes info
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Pemesan: ${widget.order.customerName}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('HH:mm:ss').format(widget.order.receivedAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),

            if (widget.order.orderNotes != null && widget.order.orderNotes!.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.note_alt, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan: ${widget.order.orderNotes}',
                          style: TextStyle(color: Colors.brown.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const Divider(height: 16),

            // 3. Item List with Fuzzy Match Badges
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: widget.order.items.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final item = widget.order.items[idx];
                  final isMatched = item.isMatched;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMatched ? Colors.grey.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMatched ? Colors.grey.shade200 : Colors.orange.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _brandColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: TextStyle(
                                  color: _brandColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.rawName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (item.price != null)
                              Text(
                                _currency.format(item.price! * item.quantity),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Match Status Badge
                        Row(
                          children: [
                            Icon(
                              isMatched ? Icons.check_circle : Icons.help_outline,
                              size: 14,
                              color: isMatched ? Colors.green : Colors.orange.shade800,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isMatched
                                    ? 'Katalog Odoo: ${item.matchedProductName} (${(item.matchConfidence * 100).toInt()}%)'
                                    : 'Belum cocok di katalog (item manual)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMatched ? Colors.green.shade800 : Colors.orange.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (item.modifiers != null && item.modifiers!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '  * Opsi: ${item.modifiers}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                        if (item.note != null && item.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '  * Note: ${item.note}',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // 4. Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            widget.deliveryService.dismissPendingOrder(widget.order.id);
                            Navigator.of(context).pop(false);
                          },
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Tolak / Abaikan', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleAcceptOrder,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.print, color: Colors.white),
                      label: Text(
                        _isProcessing ? 'Memproses Order...' : 'Terima & Cetak Dapur',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptOrder() async {
    setState(() => _isProcessing = true);

    try {
      await widget.deliveryService.acceptAndCommitOrder(
        order: widget.order,
        odooClient: widget.odooClient,
        printerService: widget.printerService,
        cashierName: widget.cashierName,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order #${widget.order.orderId} diterima! Dicetak ke dapur & tersimpan di Odoo.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Gagal memproses order: $e'),
          ),
        );
      }
    }
  }
}
