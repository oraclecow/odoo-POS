import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/order.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';
import 'admin_pin_dialog.dart';
import 'cart_item_quantity_dialog.dart';

class CartItemAdjustDialog extends StatefulWidget {
  final CartItem item;
  final PosController controller;

  const CartItemAdjustDialog({
    super.key,
    required this.item,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required CartItem item,
    required PosController controller,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CartItemAdjustDialog(
        item: item,
        controller: controller,
      ),
    );
  }

  @override
  State<CartItemAdjustDialog> createState() => _CartItemAdjustDialogState();
}

class _CartItemAdjustDialogState extends State<CartItemAdjustDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  late TextEditingController _noteController;
  late int _quantity;
  double? _discountPercent;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
    _noteController = TextEditingController(text: widget.item.note ?? '');
    _discountPercent = widget.item.discountPercent;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _incrementQty() {
    setState(() => _quantity++);
    widget.controller.setLineQuantity(widget.item.lineId, _quantity);
  }

  void _decrementQty() {
    if (_quantity > 1) {
      setState(() => _quantity--);
      widget.controller.setLineQuantity(widget.item.lineId, _quantity);
    }
  }

  Future<void> _applyDiscountWithPin(double percent) async {
    final allowedPins = <String>[
      if (widget.controller.activeCashier?.pin != null && widget.controller.activeCashier!.pin!.isNotEmpty)
        widget.controller.activeCashier!.pin!,
      '1234',
    ];

    final pinOk = await AdminPinDialog.verify(
      context,
      title: 'OTORISASI DISKON',
      message: 'Masukkan PIN Kasir / Supervisor untuk memberikan diskon ${percent.toStringAsFixed(0)}% pada ${widget.item.product.name}.',
      allowedPins: allowedPins,
    );

    if (!pinOk || !mounted) return;

    setState(() => _discountPercent = percent);
    widget.controller.applyLineDiscount(widget.item.lineId, percent);
  }

  void _removeDiscount() {
    setState(() => _discountPercent = null);
    widget.controller.applyLineDiscount(widget.item.lineId, 0.0);
  }

  Future<void> _showCustomDiscountDialog() async {
    final textCtrl = TextEditingController();
    final res = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Diskon Persen Kustom', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Persentase Diskon (%)',
                hintText: 'Cth: 12.5 atau 25',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepSlate, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(textCtrl.text.trim().replaceAll(',', '.'));
              if (val != null && val > 0 && val <= 100) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );

    if (res != null && mounted) {
      await _applyDiscountWithPin(res);
    }
  }

  void _saveAndClose() {
    final note = _noteController.text.trim();
    widget.controller.setLineNote(widget.item.lineId, note.isNotEmpty ? note : null);
    Navigator.pop(context);
  }

  void _deleteItem() {
    widget.controller.removeItem(widget.item.lineId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final basePrice = widget.item.originalUnitPrice;
    final currentUnitPrice = widget.item.unitPrice;
    final lineTotal = currentUnitPrice * _quantity;
    final hasDiscount = _discountPercent != null && _discountPercent! > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.product.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                        if (widget.item.modifiers.summaryDescription.isNotEmpty &&
                            widget.item.modifiers.summaryDescription != 'Normal (Default)') ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.item.modifiers.summaryDescription,
                            style: const TextStyle(fontSize: 12, color: AppColors.arawaliOrange, fontWeight: FontWeight.w700),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (hasDiscount) ...[
                              Text(
                                _currency.format(basePrice),
                                style: const TextStyle(
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _currency.format(currentUnitPrice),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: hasDiscount ? AppColors.arawaliOrange : AppColors.textPrimary,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-${_discountPercent!.toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantity Stepper
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.deepSlate.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jumlah (Qty):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 1 ? _decrementQty : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                              color: _quantity > 1 ? AppColors.deepSlate : Colors.grey.shade400,
                            ),
                            InkWell(
                              onTap: () async {
                                final res = await CartItemQuantityDialog.show(
                                  context,
                                  productName: widget.item.product.name,
                                  unitPrice: currentUnitPrice,
                                  initialQuantity: _quantity,
                                  sku: widget.item.product.defaultCode,
                                );
                                if (res != null && mounted) {
                                  setState(() => _quantity = res);
                                  widget.controller.setLineQuantity(widget.item.lineId, _quantity);
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Tooltip(
                                message: 'Ketik jumlah (Numpad)',
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 46),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.arawaliOrange, width: 1.5),
                                  ),
                                  child: Text(
                                    '$_quantity',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _incrementQty,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                              color: AppColors.arawaliOrange,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        ...[1, 2, 3, 5, 10, 12, 20, 50].map((val) {
                          final isSelected = _quantity == val;
                          return InkWell(
                            onTap: () {
                              setState(() => _quantity = val);
                              widget.controller.setLineQuantity(widget.item.lineId, val);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.deepSlate : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? AppColors.deepSlate : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                '$val',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }),
                        InkWell(
                          onTap: () async {
                            final res = await CartItemQuantityDialog.show(
                              context,
                              productName: widget.item.product.name,
                              unitPrice: currentUnitPrice,
                              initialQuantity: _quantity,
                              sku: widget.item.product.defaultCode,
                            );
                            if (res != null && mounted) {
                              setState(() => _quantity = res);
                              widget.controller.setLineQuantity(widget.item.lineId, _quantity);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.dialpad_rounded, size: 12, color: Colors.amber.shade900),
                                const SizedBox(width: 3),
                                Text(
                                  'Numpad',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Item Note Field
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Catatan Item (Opsional)',
                  hintText: 'Cth: Less ice, gula sedikit, tanpa sedotan...',
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Diskon Item Section (with PIN authorization)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.arawaliOrange),
                          SizedBox(width: 4),
                          Text(
                            'Diskon Item (Butuh PIN)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      if (hasDiscount)
                        TextButton(
                          onPressed: _removeDiscount,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Hapus Diskon', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Preset Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in [5.0, 10.0, 15.0, 20.0, 50.0])
                        OutlinedButton(
                          onPressed: () => _applyDiscountWithPin(p),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _discountPercent == p ? AppColors.sunYellow : Colors.white,
                            side: BorderSide(
                              color: _discountPercent == p ? AppColors.borderDark : Colors.grey.shade300,
                              width: _discountPercent == p ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            '${p.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _discountPercent == p ? AppColors.pitchBlack : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _showCustomDiscountDialog,
                        icon: const Icon(Icons.edit_rounded, size: 13),
                        label: const Text('Kustom %'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Total Preview Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.deepSlate,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Item:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      _currency.format(lineTotal),
                      style: const TextStyle(color: AppColors.sunYellow, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Bottom Actions
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _deleteItem,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                    label: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveAndClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepSlate,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Simpan / Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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
