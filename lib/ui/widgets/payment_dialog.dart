import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/services/odoo_client.dart';
import '../core/app_colors.dart';
import 'touch_numpad.dart';

class PaymentResult {
  final String paymentMethod;
  final int tenderedAmount;
  final int changeAmount;
  final PosOrderSubmissionResult? submissionResult;

  const PaymentResult({
    required this.paymentMethod,
    required this.tenderedAmount,
    required this.changeAmount,
    this.submissionResult,
  });
}

class PaymentDialog extends StatefulWidget {
  final int totalAmount;
  final Future<PosOrderSubmissionResult?> Function({
    required String paymentMethod,
    required int tenderedAmount,
    required int changeAmount,
  }) onConfirmPayment;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onConfirmPayment,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  late final FocusNode _focusNode;

  String _selectedMethod = 'Cash'; // 'Cash', 'Transfer', 'QRIS'
  int _tenderedAmount = 0;
  bool _isSubmitting = false;
  bool _isFirstInput = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Default to exact payment ("Uang Pas") so cashier can submit immediately
    _tenderedAmount = widget.totalAmount;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isRefund => widget.totalAmount < 0;

  int get _changeAmount {
    if (_isRefund) return 0;
    if (_selectedMethod != 'Cash') return 0;
    final diff = _tenderedAmount - widget.totalAmount;
    return diff > 0 ? diff : 0;
  }

  bool get _isPaymentValid {
    if (_isRefund) return true;
    if (_selectedMethod != 'Cash') return true;
    return _tenderedAmount >= widget.totalAmount;
  }

  void _addBill(int bill) {
    setState(() {
      if (_isFirstInput) {
        _isFirstInput = false;
        _tenderedAmount = bill;
      } else {
        _tenderedAmount += bill;
      }
    });
  }

  void _setBillDirect(int bill) {
    setState(() {
      _isFirstInput = false;
      _tenderedAmount = bill;
    });
  }

  void _setExact() {
    setState(() {
      _isFirstInput = true;
      _tenderedAmount = widget.totalAmount;
    });
  }

  void _clearBills() {
    setState(() {
      _isFirstInput = false;
      _tenderedAmount = 0;
    });
  }

  void _onNumpadKeyPress(String val) {
    setState(() {
      if (_isFirstInput) {
        _isFirstInput = false;
        if (val == '00' || val == '000') {
          _tenderedAmount = 0;
        } else {
          _tenderedAmount = int.tryParse(val) ?? 0;
        }
        return;
      }

      if (val == '00') {
        if (_tenderedAmount > 0 && _tenderedAmount < 10000000) {
          _tenderedAmount *= 100;
        }
        return;
      }

      if (val == '000') {
        if (_tenderedAmount > 0 && _tenderedAmount < 1000000) {
          _tenderedAmount *= 1000;
        }
        return;
      }

      final currentStr = _tenderedAmount == 0 ? '' : _tenderedAmount.toString();
      final newStr = currentStr + val;
      if (newStr.length > 9) return;
      _tenderedAmount = int.tryParse(newStr) ?? _tenderedAmount;
    });
  }

  void _onNumpadBackspace() {
    setState(() {
      _isFirstInput = false;
      final s = _tenderedAmount.toString();
      if (s.length <= 1) {
        _tenderedAmount = 0;
      } else {
        _tenderedAmount = int.tryParse(s.substring(0, s.length - 1)) ?? 0;
      }
    });
  }

  void _onNumpadClear() {
    setState(() {
      _isFirstInput = false;
      _tenderedAmount = 0;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // 1. Enter or NumpadEnter: submit payment if valid
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_isPaymentValid && !_isSubmitting) {
        _submit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 2. Escape: close dialog
    if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    // Only handle cash inputs when Cash is selected and not a refund
    if (_selectedMethod == 'Cash' && !_isRefund) {
      String? digit;
      if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) digit = '0';
      else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) digit = '1';
      else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) digit = '2';
      else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) digit = '3';
      else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) digit = '4';
      else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) digit = '5';
      else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) digit = '6';
      else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) digit = '7';
      else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) digit = '8';
      else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) digit = '9';

      if (digit != null) {
        _onNumpadKeyPress(digit);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.backspace) {
        _onNumpadBackspace();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.keyC) {
        _onNumpadClear();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyP) {
        _setExact();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _submit() async {
    if (!_isPaymentValid || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final finalTendered = _isRefund ? widget.totalAmount : (_selectedMethod == 'Cash' ? _tenderedAmount : widget.totalAmount);
    final finalChange = _changeAmount;
    try {
      final submissionResult = await widget.onConfirmPayment(
        paymentMethod: _selectedMethod,
        tenderedAmount: finalTendered,
        changeAmount: finalChange,
      );
      if (mounted) {
        Navigator.pop(
          context,
          PaymentResult(
            paymentMethod: _selectedMethod,
            tenderedAmount: finalTendered,
            changeAmount: finalChange,
            submissionResult: submissionResult,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim ke Odoo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth >= 920 && _selectedMethod == 'Cash' && !_isRefund;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 820 : 540,
          maxHeight: screenHeight * 0.92,
        ),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Pick A Juice Brand
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/images/store_logo.png', height: 32, fit: BoxFit.contain),
                        const SizedBox(width: 10),
                        const Text(
                          'OPEN ODOO POS CHECKOUT',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: AppColors.divider),
                const SizedBox(height: 4),

                // Content Area
                Flexible(
                  child: SingleChildScrollView(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Total Due, Method, Tendered & Change, Presets
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTotalDueBanner(),
                                    const SizedBox(height: 14),
                                    _buildPaymentMethodSection(),
                                    const SizedBox(height: 14),
                                    _buildCashCalculationCard(),
                                    const SizedBox(height: 14),
                                    _buildQuickCashPresets(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Right Column: Touch Numpad
                              Expanded(
                                flex: 4,
                                child: _buildNumpadSection(),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTotalDueBanner(),
                              const SizedBox(height: 14),
                              _buildPaymentMethodSection(),
                              const SizedBox(height: 14),
                              if (_isRefund) ...[
                                _buildRefundBanner(),
                                const SizedBox(height: 14),
                              ] else if (_selectedMethod == 'Cash') ...[
                                _buildCashCalculationCard(),
                                const SizedBox(height: 14),
                                _buildNumpadSection(),
                                const SizedBox(height: 14),
                                _buildQuickCashPresets(),
                              ] else ...[
                                _buildNonCashDetails(),
                              ],
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 10),

                // Keyboard shortcuts guide
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_outlined, size: 16, color: Color(0xFF475569)),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '[0-9] Ketik Nominal  •  [Enter] Bayar  •  [Space / P] Uang Pas  •  [C] Reset  •  [Esc] Batal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Fixed Bottom Action Bar: ALWAYS visible and NEVER covered
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isPaymentValid && !_isSubmitting ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sunYellow,
                      foregroundColor: AppColors.pitchBlack,
                      disabledBackgroundColor: const Color(0xFF334155),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.borderDark, width: 2.5),
                      ),
                    ),
                    child: _isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.pitchBlack, strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text('Submitting to Odoo...', style: TextStyle(color: AppColors.pitchBlack, fontWeight: FontWeight.w900)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.pitchBlack, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isPaymentValid
                                      ? 'Bayar & Cetak Struk [Enter]'
                                      : 'Nominal Belum Cukup (${_currency.format(widget.totalAmount - _tenderedAmount)})',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.pitchBlack),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalDueBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isRefund ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRefund ? Colors.red.shade300 : AppColors.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isRefund ? 'Total Refund (Kembalikan):' : 'Total Due:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isRefund ? Colors.red.shade900 : AppColors.textPrimary,
            ),
          ),
          Text(
            _currency.format(_isRefund ? widget.totalAmount.abs() : widget.totalAmount),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _isRefund ? Colors.red.shade700 : AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMethodChip('Cash', Icons.payments_rounded),
            const SizedBox(width: 8),
            _buildMethodChip('Transfer', Icons.account_balance_rounded),
            const SizedBox(width: 8),
            _buildMethodChip('QRIS', Icons.qr_code_2_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildRefundBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kembalikan dana sebesar ${_currency.format(widget.totalAmount.abs())} secara tunai / cash ke pelanggan.',
              style: TextStyle(color: Colors.red.shade900, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashCalculationCard() {
    return InkWell(
      onTap: () => _focusNode.requestFocus(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Cash Tendered:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (_tenderedAmount == widget.totalAmount && _isFirstInput) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Pas',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _currency.format(_tenderedAmount),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.pitchBlack),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Change Due (Kembalian):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  _currency.format(_changeAmount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _changeAmount > 0 ? Colors.green.shade800 : Colors.black87,
                  ),
                ),
              ],
            ),
            if (!_isPaymentValid) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      'Kurang: ${_currency.format(widget.totalAmount - _tenderedAmount)}',
                      style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCashPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Cash Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _setExact,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text('Uang Pas (${_currency.format(widget.totalAmount).replaceAll('Rp ', '')})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tenderedAmount == widget.totalAmount ? AppColors.primaryGreen : Colors.green.shade50,
                foregroundColor: _tenderedAmount == widget.totalAmount ? Colors.white : Colors.green.shade800,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            // Common notes
            ...[50000, 100000].where((b) => b >= widget.totalAmount).map((bill) {
              final isSelected = _tenderedAmount == bill;
              return ElevatedButton(
                onPressed: () => _setBillDirect(bill),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue.shade700 : Colors.blue.shade50,
                  foregroundColor: isSelected ? Colors.white : Colors.blue.shade800,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: Text(
                  'Rp ${_currency.format(bill).replaceAll('Rp ', '')}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _clearBills,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Reset (C)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Touch / Numpad',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                '⌨️ Keyboard Aktif',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TouchNumpad(
          onKeyPress: _onNumpadKeyPress,
          onBackspace: _onNumpadBackspace,
          onClear: _onNumpadClear,
          quickAddAmounts: const [10000, 20000, 50000, 100000],
          onQuickAdd: _addBill,
          onExact: _setExact,
          exactLabel: 'Pas',
          showZeroShortcuts: true,
          showCornerKey: true,
        ),
      ],
    );
  }

  Widget _buildNonCashDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            _selectedMethod == 'QRIS' ? Icons.qr_code_scanner_rounded : Icons.account_balance_wallet_rounded,
            size: 36,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedMethod Settlement',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Exact payment of ${_currency.format(widget.totalAmount)} will be posted to Odoo POS journal.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodChip(String method, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = method),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.sunYellow : AppColors.deepSlate,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.borderDark,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.pitchBlack : AppColors.pureWhite),
              const SizedBox(width: 6),
              Text(
                method,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppColors.pitchBlack : AppColors.pureWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
