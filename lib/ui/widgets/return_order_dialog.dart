import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/odoo_client.dart';
import '../core/app_colors.dart';

class ReturnItemSelection {
  final int productId;
  final String productName;
  final int unitPrice;
  final int returnQty;
  final String returnRef;

  const ReturnItemSelection({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.returnQty,
    required this.returnRef,
  });
}

class ReturnOrderDialog extends StatefulWidget {
  final OdooOrderRecord order;
  final List<Map<String, dynamic>> lines;

  const ReturnOrderDialog({
    super.key,
    required this.order,
    required this.lines,
  });

  static Future<List<ReturnItemSelection>?> show(
    BuildContext context, {
    required OdooOrderRecord order,
    required List<Map<String, dynamic>> lines,
  }) async {
    return await showDialog<List<ReturnItemSelection>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ReturnOrderDialog(order: order, lines: lines),
    );
  }

  @override
  State<ReturnOrderDialog> createState() => _ReturnOrderDialogState();
}

class _ReturnOrderDialogState extends State<ReturnOrderDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final Map<int, int> _selectedReturnQtys = {}; // line index -> return qty
  final TextEditingController _reasonController = TextEditingController(text: 'Retur Pelanggan');

  @override
  void initState() {
    super.initState();
    // Default: select 1 unit for each item
    for (int i = 0; i < widget.lines.length; i++) {
      final line = widget.lines[i];
      final origQty = ((line['qty'] as num?) ?? 1).toInt();
      if (origQty > 0) {
        _selectedReturnQtys[i] = 1;
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _totalRefundAmount {
    int sum = 0;
    for (int i = 0; i < widget.lines.length; i++) {
      final returnQty = _selectedReturnQtys[i] ?? 0;
      if (returnQty > 0) {
        final line = widget.lines[i];
        final priceUnit = ((line['price_unit'] as num?) ?? 0).toInt();
        sum += priceUnit * returnQty;
      }
    }
    return sum;
  }

  int get _totalReturnItemsCount {
    return _selectedReturnQtys.values.fold(0, (sum, q) => sum + q);
  }

  static String resolveLineProductName(Map<String, dynamic> line) {
    final fpn = line['full_product_name'];
    if (fpn is String && fpn.trim().isNotEmpty && fpn.trim().toLowerCase() != 'false') {
      return fpn.trim();
    }
    final pid = line['product_id'];
    if (pid is List && pid.length > 1 && pid[1] != null) {
      final raw = pid[1].toString().trim();
      final match = RegExp(r'^\[.*?\]\s*(.*)$').firstMatch(raw);
      return (match != null && match.group(1)?.trim().isNotEmpty == true)
          ? match.group(1)!.trim()
          : raw;
    }
    if (line['name'] is String && (line['name'] as String).trim().isNotEmpty) {
      return (line['name'] as String).trim();
    }
    return 'Item';
  }

  void _onConfirm() {
    final selections = <ReturnItemSelection>[];
    final ref = widget.order.posReference.isNotEmpty ? widget.order.posReference : widget.order.name;
    final reason = _reasonController.text.trim();
    final returnNote = reason.isNotEmpty ? '$ref ($reason)' : ref;

    for (int i = 0; i < widget.lines.length; i++) {
      final returnQty = _selectedReturnQtys[i] ?? 0;
      if (returnQty > 0) {
        final line = widget.lines[i];
        final prodIdVal = line['product_id'];
        final prodId = prodIdVal is List ? (prodIdVal[0] as int) : (prodIdVal as int? ?? 0);
        final prodName = resolveLineProductName(line);
        final priceUnit = ((line['price_unit'] as num?) ?? 0).toInt();

        selections.add(ReturnItemSelection(
          productId: prodId,
          productName: prodName,
          unitPrice: priceUnit,
          returnQty: returnQty,
          returnRef: returnNote,
        ));
      }
    }

    Navigator.pop(context, selections);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: screenHeight * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_return_rounded, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RETUR BARANG (REFUND)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Order: ${widget.order.name} • ${widget.order.partnerName}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Return Reason Input
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Alasan Retur / Catatan',
                  hintText: 'Contoh: Salah beli, barang rusak, cacat kemasan',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Pilih Item & Jumlah Yang Diretur:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),

              // Items List
              Expanded(
                child: widget.lines.isEmpty
                    ? const Center(
                        child: Text('Tidak ada rincian item pada nota ini.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.separated(
                        itemCount: widget.lines.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final line = widget.lines[index];
                          final prodName = resolveLineProductName(line);
                          final origQty = ((line['qty'] as num?) ?? 1).toInt();
                          final priceUnit = ((line['price_unit'] as num?) ?? 0).toInt();
                          final currentReturnQty = _selectedReturnQtys[index] ?? 0;
                          final isSelected = currentReturnQty > 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.red.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? Colors.red.shade300 : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: Colors.red,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedReturnQtys[index] = 1;
                                      } else {
                                        _selectedReturnQtys[index] = 0;
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prodName,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Beli: $origQty item @ ${_currency.format(priceUnit)}',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                // Stepper (- qty +)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: currentReturnQty > 0
                                          ? () => setState(() => _selectedReturnQtys[index] = currentReturnQty - 1)
                                          : null,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        '$currentReturnQty',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: isSelected ? Colors.red.shade900 : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: currentReturnQty < origQty
                                          ? () => setState(() => _selectedReturnQtys[index] = currentReturnQty + 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),

              // Total Refund Summary Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Nilai Retur:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          '$_totalReturnItemsCount item dipilih',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      _currency.format(_totalRefundAmount),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                      label: const Text('Muat ke Kasir (Retur)', style: TextStyle(fontWeight: FontWeight.w900)),
                      onPressed: _totalReturnItemsCount > 0 ? _onConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
