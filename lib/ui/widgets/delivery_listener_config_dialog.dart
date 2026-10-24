import 'package:flutter/material.dart';
import '../../data/models/delivery_order.dart';
import '../../data/models/order.dart';
import '../../data/services/delivery/delivery_order_service.dart';
import '../core/app_colors.dart';

class DeliveryListenerConfigDialog extends StatefulWidget {
  final DeliveryOrderService deliveryService;

  const DeliveryListenerConfigDialog({
    super.key,
    required this.deliveryService,
  });

  static void show(BuildContext context, DeliveryOrderService deliveryService) {
    showDialog(
      context: context,
      builder: (ctx) => DeliveryListenerConfigDialog(deliveryService: deliveryService),
    );
  }

  @override
  State<DeliveryListenerConfigDialog> createState() => _DeliveryListenerConfigDialogState();
}

class _DeliveryListenerConfigDialogState extends State<DeliveryListenerConfigDialog> {
  late TextEditingController _portController;
  bool _isAccessibilityActive = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: widget.deliveryService.port.toString());
    _checkAccessibility();
  }

  Future<void> _checkAccessibility() async {
    final active = await widget.deliveryService.isAccessibilityServiceEnabled();
    if (mounted) {
      setState(() => _isAccessibilityActive = active);
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.deliveryService;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B14F).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delivery_dining, color: Color(0xFF00B14F), size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Listener Settings',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'GrabFood & ShopeeFood Order Intake',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Server Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: s.isServerRunning ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: s.isServerRunning ? Colors.green.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.isServerRunning ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: s.isServerRunning ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.isServerRunning
                                ? 'Wi-Fi Listener AKTIF di Port :${s.port}'
                                : 'Wi-Fi Listener NON-AKTIF',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: s.isServerRunning ? Colors.green.shade900 : Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            s.isServerRunning
                                ? 'HP Kasir mengirim order ke: http://<IP_TABLET>:${s.port}/api/delivery/order'
                                : 'Aktifkan listener agar dapat menerima pesanan dari HP kasir.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.isEnabled,
                      activeColor: const Color(0xFF00B14F),
                      onChanged: (val) async {
                        await s.setEnabled(val);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Settings Form
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HTTP Port',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.check, size: 18),
                                onPressed: () {
                                  final p = int.tryParse(_portController.text);
                                  if (p != null) {
                                    s.setPort(p);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Port diubah ke $p')),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cetak Dapur Otomatis',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                s.autoPrint ? 'Auto Print ON' : 'Manual Print',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Switch(
                                value: s.autoPrint,
                                activeColor: AppColors.tropicalCyan,
                                onChanged: (val) => s.setAutoPrint(val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Dormant On-Device Grab Listener section
              const Text(
                'On-Device Grab Listener (Dormant Mode)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Jika suatu saat GrabMerchant dijalankan langsung di tablet ini, aktifkan layanan aksesibilitas agar order terbaca otomatis.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isAccessibilityActive ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isAccessibilityActive ? Colors.green.shade200 : Colors.amber.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAccessibilityActive ? Icons.check_circle : Icons.info_outline,
                      size: 18,
                      color: _isAccessibilityActive ? Colors.green : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isAccessibilityActive
                            ? 'Layanan Aksesibilitas: AKTIF di Tablet'
                            : 'Layanan Aksesibilitas: DORMANT (Mati)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isAccessibilityActive ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await s.openAccessibilitySettings();
                        await Future.delayed(const Duration(seconds: 1));
                        _checkAccessibility();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Buka Pengaturan', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Test Simulation Button
              OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow, color: Color(0xFF00B14F)),
                label: const Text('Kirim Test Order GrabFood (Simulasi)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  // Generate a test order
                  final testOrder = IncomingDeliveryOrder(
                    id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
                    orderId: 'GF-${(1000 + DateTime.now().second * 17)}',
                    channelType: OrderChannelType.grabFood,
                    customerName: 'Candra (Test)',
                    orderNotes: 'Jangan terlalu manis, minta sendok',
                    items: [
                      const IncomingDeliveryItem(
                        rawName: 'PEANUT Toast',
                        quantity: 1,
                        price: 18000,
                        note: 'Panggang agak garing',
                      ),
                      const IncomingDeliveryItem(
                        rawName: 'Jus Alpukat',
                        quantity: 1,
                        price: 15000,
                        modifiers: 'Less Sugar',
                      ),
                    ],
                  );

                  // Process in service
                  final res = await s.processIncomingOrder(testOrder);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Simulasi order #${testOrder.orderId} terkirim: $res'),
                        backgroundColor: const Color(0xFF00B14F),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
