import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';

class DiscountDialog extends StatefulWidget {
  final int subtotal;
  final double currentPercent;
  final int currentAmount;

  const DiscountDialog({
    super.key,
    required this.subtotal,
    this.currentPercent = 0.0,
    this.currentAmount = 0,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required int subtotal,
    double currentPercent = 0.0,
    int currentAmount = 0,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DiscountDialog(
        subtotal: subtotal,
        currentPercent: currentPercent,
        currentAmount: currentAmount,
      ),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isPercentMode = true;
  String _inputVal = '';

  final _quickPercents = const [5, 10, 15, 20, 25, 50];
  final _quickAmounts = const [2000, 5000, 10000, 20000, 50000];

  @override
  void initState() {
    super.initState();
    if (widget.currentPercent > 0) {
      _isPercentMode = true;
      _inputVal = widget.currentPercent.toStringAsFixed(0);
    } else if (widget.currentAmount > 0) {
      _isPercentMode = false;
      _inputVal = widget.currentAmount.toString();
    }
  }

  int get _calculatedDiscount {
    final parsed = double.tryParse(_inputVal) ?? 0.0;
    if (_isPercentMode) {
      final clamped = parsed.clamp(0.0, 100.0);
      return ((widget.subtotal * clamped) / 100.0).round();
    } else {
      return parsed.toInt().clamp(0, widget.subtotal > 0 ? widget.subtotal : 0);
    }
  }

  int get _finalTotal => (widget.subtotal - _calculatedDiscount).clamp(0, widget.subtotal);

  void _onKeyPress(String digit) {
    if (_isPercentMode) {
      if (_inputVal.length >= 3) return;
      final nextVal = '$_inputVal$digit';
      final parsed = int.tryParse(nextVal) ?? 0;
      if (parsed <= 100) {
        setState(() => _inputVal = nextVal);
      }
    } else {
      if (_inputVal.length >= 8) return;
      setState(() => _inputVal = '$_inputVal$digit');
    }
  }

  void _onBackspace() {
    if (_inputVal.isNotEmpty) {
      setState(() => _inputVal = _inputVal.substring(0, _inputVal.length - 1));
    }
  }

  void _onClear() {
    setState(() => _inputVal = '');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          color: AppColors.sunYellow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.discount_rounded, color: AppColors.arawaliOrange, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'DISKON KERANJANG',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Mode Switcher: Persen (%) vs Nominal (Rp)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isPercentMode = true;
                            _inputVal = '';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isPercentMode ? AppColors.sunYellow : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Persen (%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _isPercentMode ? AppColors.pitchBlack : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isPercentMode = false;
                            _inputVal = '';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !_isPercentMode ? AppColors.sunYellow : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Nominal (Rp)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: !_isPercentMode ? AppColors.pitchBlack : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Summary Preview Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.deepSlate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal Sebelum Diskon:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                        Text(_currency.format(widget.subtotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPercentMode ? 'Diskon ($_inputVal%):' : 'Potongan Diskon:',
                          style: const TextStyle(color: AppColors.sunYellow, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '-${_currency.format(_calculatedDiscount)}',
                          style: const TextStyle(color: AppColors.sunYellow, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF475569), height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Setelah Diskon:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                        Text(_currency.format(_finalTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Quick Preset Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _isPercentMode
                    ? _quickPercents.map((p) {
                        return ActionChip(
                          label: Text('$p%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          backgroundColor: _inputVal == '$p' ? AppColors.sunYellow : Colors.grey.shade200,
                          onPressed: () => setState(() => _inputVal = '$p'),
                        );
                      }).toList()
                    : _quickAmounts.map((a) {
                        return ActionChip(
                          label: Text(_currency.format(a), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: _inputVal == '$a' ? AppColors.sunYellow : Colors.grey.shade200,
                          onPressed: () => setState(() => _inputVal = '$a'),
                        );
                      }).toList(),
              ),
              const SizedBox(height: 12),

              // Numeric Input Display & Keypad
              Container(
                height: 44,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _inputVal.isEmpty ? '0' : (_isPercentMode ? '$_inputVal %' : _currency.format(int.tryParse(_inputVal) ?? 0)),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 10),

              // Compact Keypad
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                    OutlinedButton(
                      onPressed: () => _onKeyPress(d),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(d, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  OutlinedButton(
                    onPressed: _onClear,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('C', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                  OutlinedButton(
                    onPressed: () => _onKeyPress('0'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton(
                    onPressed: _onBackspace,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.backspace_outlined, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, {'clear': true});
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Hapus Diskon', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _calculatedDiscount > 0
                          ? () {
                              if (_isPercentMode) {
                                Navigator.pop(context, {
                                  'percent': double.tryParse(_inputVal) ?? 0.0,
                                  'amount': 0,
                                });
                              } else {
                                Navigator.pop(context, {
                                  'percent': 0.0,
                                  'amount': int.tryParse(_inputVal) ?? 0,
                                });
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sunYellow,
                        foregroundColor: AppColors.pitchBlack,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.w900)),
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
