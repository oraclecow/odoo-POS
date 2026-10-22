import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import 'touch_numpad.dart';

class CartItemQuantityDialog extends StatefulWidget {
  final String productName;
  final int unitPrice;
  final int initialQuantity;
  final String? sku;
  final int? originalUnitPrice;
  final double? discountPercent;

  const CartItemQuantityDialog({
    super.key,
    required this.productName,
    required this.unitPrice,
    required this.initialQuantity,
    this.sku,
    this.originalUnitPrice,
    this.discountPercent,
  });

  static Future<int?> show(
    BuildContext context, {
    required String productName,
    required int unitPrice,
    required int initialQuantity,
    String? sku,
    int? originalUnitPrice,
    double? discountPercent,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CartItemQuantityDialog(
        productName: productName,
        unitPrice: unitPrice,
        initialQuantity: initialQuantity,
        sku: sku,
        originalUnitPrice: originalUnitPrice,
        discountPercent: discountPercent,
      ),
    );
  }

  @override
  State<CartItemQuantityDialog> createState() => _CartItemQuantityDialogState();
}

class _CartItemQuantityDialogState extends State<CartItemQuantityDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  late int _quantity;
  bool _isFirstInput = true;

  final List<int> _quickPresets = const [1, 10, 12, 24, 48];

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
  }

  void _onKeyPress(String key) {
    setState(() {
      if (_isFirstInput) {
        _isFirstInput = false;
        _quantity = int.tryParse(key) ?? 1;
      } else {
        final str = '$_quantity$key';
        if (str.length <= 4) {
          _quantity = int.tryParse(str) ?? _quantity;
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _isFirstInput = false;
      final str = '$_quantity';
      if (str.length <= 1) {
        _quantity = 0;
      } else {
        _quantity = int.tryParse(str.substring(0, str.length - 1)) ?? 0;
      }
    });
  }

  void _onClear() {
    setState(() {
      _isFirstInput = false;
      _quantity = 0;
    });
  }

  void _setPreset(int val) {
    setState(() {
      _isFirstInput = false;
      _quantity = val;
    });
  }

  void _confirm() {
    if (_quantity <= 0) {
      Navigator.pop(context, 0); // 0 indicates remove or cancel
    } else {
      Navigator.pop(context, _quantity);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _confirm();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.keyC) {
      _onClear();
      return KeyEventResult.handled;
    }

    // Number keys
    final char = event.character;
    if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
      _onKeyPress(char);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = (widget.discountPercent != null && widget.discountPercent! > 0)
        ? ((widget.originalUnitPrice ?? widget.unitPrice) * _quantity * (1.0 - widget.discountPercent! / 100.0)).round()
        : widget.unitPrice * _quantity;
    final screenHeight = MediaQuery.of(context).size.height;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: screenHeight * 0.90,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.sku != null ? "[${widget.sku}] " : ""}${_currency.format(widget.unitPrice)} / pcs',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                const SizedBox(height: 10),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Large Quantity & Subtotal Preview Display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.sunYellow.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.sunYellow, width: 2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'JUMLAH (QTY):',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.pitchBlack,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_quantity',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.pitchBlack,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Estimasi Total:',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currency.format(subtotal),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryGreen,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Quick Quantity Presets
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: _quickPresets.map((val) {
                            final isSelected = _quantity == val;
                            return InkWell(
                              onTap: () => _setPreset(val),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.pitchBlack : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppColors.pitchBlack : const Color(0xFFCBD5E1),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$val',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),

                        // 3x4 Touch Numpad (compact for quantities)
                        TouchNumpad(
                          onKeyPress: _onKeyPress,
                          onBackspace: _onBackspace,
                          onClear: _onClear,
                          showZeroShortcuts: false,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons: Batal & Terapkan
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        onPressed: _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          _quantity <= 0 ? 'Hapus Item' : 'Terapkan ($_quantity)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
