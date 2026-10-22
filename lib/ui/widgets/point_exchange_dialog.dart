import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/customer.dart';
import '../core/app_colors.dart';

class PointExchangeDialog extends StatefulWidget {
  final Customer customer;
  final int subtotal;
  final int currentRedeemedPoints;

  const PointExchangeDialog({
    super.key,
    required this.customer,
    required this.subtotal,
    this.currentRedeemedPoints = 0,
  });

  static Future<int?> show(
    BuildContext context, {
    required Customer customer,
    required int subtotal,
    int currentRedeemedPoints = 0,
  }) async {
    return await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PointExchangeDialog(
        customer: customer,
        subtotal: subtotal,
        currentRedeemedPoints: currentRedeemedPoints,
      ),
    );
  }

  @override
  State<PointExchangeDialog> createState() => _PointExchangeDialogState();
}

class _PointExchangeDialogState extends State<PointExchangeDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  String _inputPts = '';

  @override
  void initState() {
    super.initState();
    if (widget.currentRedeemedPoints > 0) {
      _inputPts = widget.currentRedeemedPoints.toString();
    }
  }

  int get _maxPointsAvailable => widget.customer.points.toInt();
  int get _maxRedeemable => _maxPointsAvailable < widget.subtotal ? _maxPointsAvailable : widget.subtotal;

  int get _enteredPoints {
    final parsed = int.tryParse(_inputPts) ?? 0;
    return parsed.clamp(0, _maxRedeemable);
  }

  void _onKeyPress(String digit) {
    if (_inputPts.length >= 7) return;
    final nextVal = '$_inputPts$digit';
    final parsed = int.tryParse(nextVal) ?? 0;
    if (parsed <= _maxRedeemable) {
      setState(() => _inputPts = nextVal);
    } else {
      setState(() => _inputPts = _maxRedeemable.toString());
    }
  }

  void _onBackspace() {
    if (_inputPts.isNotEmpty) {
      setState(() => _inputPts = _inputPts.substring(0, _inputPts.length - 1));
    }
  }

  void _onClear() {
    setState(() => _inputPts = '');
  }

  void _onRedeemAll() {
    setState(() => _inputPts = _maxRedeemable.toString());
  }

  @override
  Widget build(BuildContext context) {
    final remainingPoints = (_maxPointsAvailable - _enteredPoints).clamp(0, _maxPointsAvailable);
    final finalPayable = (widget.subtotal - _enteredPoints).clamp(0, widget.subtotal);

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
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TUKAR POIN LOYALTY',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                          Text(
                            '1 Poin = Rp 1 Potongan',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 14),

              // Customer & Points Summary Card
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
                        Text('Member: ${widget.customer.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sunYellow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '⭐ $_maxPointsAvailable Pts',
                            style: const TextStyle(color: AppColors.pitchBlack, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF475569), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal Belanja:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                        Text(_currency.format(widget.subtotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Potongan Poin:', style: TextStyle(color: AppColors.sunYellow, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('-${_currency.format(_enteredPoints)}', style: const TextStyle(color: AppColors.sunYellow, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sisa Poin Member:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        Text('$remainingPoints Pts', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                      ],
                    ),
                    const Divider(color: Color(0xFF475569), height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Bayar:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                        Text(_currency.format(finalPayable), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Quick "Tukar Semua" button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Maksimal Tukar: $_maxRedeemable Pts',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: _onRedeemAll,
                    icon: const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.arawaliOrange),
                    label: const Text('Tukar Semua', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.arawaliOrange)),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Points Input Box
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
                  _inputPts.isEmpty ? '0 Poin' : '$_inputPts Poin (${_currency.format(_enteredPoints)})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 10),

              // Keypad
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
                      onPressed: () => Navigator.pop(context, 0), // 0 to clear
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Hapus Poin', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _enteredPoints > 0
                          ? () => Navigator.pop(context, _enteredPoints)
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
