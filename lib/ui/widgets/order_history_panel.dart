import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/odoo_client.dart';
import '../../data/services/printer/printer_service.dart';
import '../../data/models/juice_product.dart';
import '../../data/models/floating_order.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';
import 'admin_pin_dialog.dart';
import 'return_order_dialog.dart';

class OrderHistoryPanel extends StatefulWidget {
  final OdooClient odooClient;
  final PrinterService printerService;
  final PosController? controller;
  final VoidCallback onBackToRegister;

  const OrderHistoryPanel({
    super.key,
    required this.odooClient,
    required this.printerService,
    this.controller,
    required this.onBackToRegister,
  });

  @override
  State<OrderHistoryPanel> createState() => _OrderHistoryPanelState();
}

class _OrderHistoryPanelState extends State<OrderHistoryPanel> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isLoading = true;
  List<OdooOrderRecord> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await widget.odooClient.fetchRecentOrders(30);
      setState(() {
        _orders = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                      onPressed: widget.onBackToRegister,
                      tooltip: 'Kembali ke Kasir',
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Riwayat Pesanan (Order History)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryGreen),
                  tooltip: 'Segarkan dari Odoo',
                  onPressed: _loadOrders,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Ongoing Floating Orders Banner (Odoo 19 TicketScreen alignment)
          _buildFloatingOrdersSection(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('Gagal memuat riwayat: $_error', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadOrders,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _orders.isEmpty
                        ? const Center(
                            child: Text('Belum ada pesanan di sesi kasir ini.', style: TextStyle(color: AppColors.textSecondary)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _orders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0.5,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    children: [
                                      // Status icon & Order Number
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryGreen),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  order.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    order.state.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.green.shade900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Pelanggan: ${order.partnerName} • ${order.localDateOrder}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Total & Reprint Button
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _currency.format(order.amountTotal),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Retur button with PIN authorization
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.assignment_return_rounded, size: 14, color: Colors.red),
                                                label: const Text('Retur', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  side: const BorderSide(color: Colors.red),
                                                ),
                                                onPressed: () async {
                                                  final allowedPins = [
                                                    widget.controller?.activeCashier?.pin,
                                                  ].whereType<String>().toList();

                                                  final ok = await AdminPinDialog.verify(
                                                    context,
                                                    title: 'OTORISASI RETUR BARANG',
                                                    message: 'Masukkan PIN Supervisor atau Kasir untuk proses retur.',
                                                    allowedPins: allowedPins,
                                                  );
                                                  if (!ok || !context.mounted) return;

                                                  List<Map<String, dynamic>> lines = [];
                                                  try {
                                                    lines = await widget.odooClient.fetchOrderLines(order.id);
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Gagal mengambil rincian nota: $e'), backgroundColor: Colors.red),
                                                      );
                                                    }
                                                    return;
                                                  }

                                                  if (!context.mounted) return;
                                                  final selections = await ReturnOrderDialog.show(
                                                    context,
                                                    order: order,
                                                    lines: lines,
                                                  );

                                                  if (selections != null && selections.isNotEmpty && context.mounted) {
                                                    for (final sel in selections) {
                                                      final existingProd = widget.controller?.filteredProducts.firstWhere(
                                                        (p) => p.id == sel.productId,
                                                        orElse: () => JuiceProduct(
                                                          id: sel.productId,
                                                          name: sel.productName,
                                                          price: sel.unitPrice,
                                                          category: 'Retur',
                                                          defaultCode: '',
                                                        ),
                                                      );
                                                      if (existingProd != null) {
                                                        widget.controller?.addReturnItem(
                                                          existingProd,
                                                          sel.returnQty,
                                                          unitPrice: sel.unitPrice,
                                                          returnRef: sel.returnRef,
                                                        );
                                                      }
                                                    }
                                                    widget.onBackToRegister();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('${selections.length} item retur berhasil dimuat ke kasir.'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                              const SizedBox(width: 6),
                                              // Reprint button
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.print_rounded, size: 14),
                                                label: const Text('Reprint', style: TextStyle(fontSize: 12)),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  side: const BorderSide(color: AppColors.border),
                                                ),
                                                onPressed: () async {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Mencetak ulang struk ${order.name}...'),
                                                      duration: const Duration(seconds: 1),
                                                    ),
                                                  );
                                                  List<Map<String, dynamic>> lines = [];
                                                  try {
                                                    lines = await widget.odooClient.fetchOrderLines(order.id);
                                                  } catch (_) {}
                                                  final res = await widget.printerService.printHistoryReceipt(
                                                    order: order,
                                                    lines: lines,
                                                    storeName: widget.odooClient.profile.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(res['message'] ?? 'Perintah cetak terkirim.'),
                                                        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingOrdersSection() {
    final controller = widget.controller;
    if (controller == null) return const SizedBox.shrink();
    final floatingOrders = controller.floatingOrders;
    final hasOngoing = floatingOrders.length > 1 || (floatingOrders.isNotEmpty && floatingOrders.first.items.isNotEmpty);
    if (!hasOngoing) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pause_circle_outline_rounded, size: 20, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Text(
                'Pesanan Berjalan / Parkir (Floating Orders)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${floatingOrders.length} Cart',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: floatingOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final order = floatingOrders[index];
              final isActive = index == controller.activeOrderIndex;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? Colors.amber.shade700 : Colors.grey.shade300,
                    width: isActive ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.sunYellow : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${order.orderNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customer != null ? 'Pelanggan: ${order.customer!.name}' : 'Umum (Tanpa Member)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          Text(
                            '${order.totalQuantity} barang • ${_currency.format(order.total)}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: Text(isActive ? 'Buka Sekarang' : 'Muat Pesanan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? AppColors.pitchBlack : Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        controller.selectFloatingOrder(index);
                        widget.onBackToRegister();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
