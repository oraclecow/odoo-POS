import 'package:flutter/material.dart';
import '../../data/services/odoo_client.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';

class CashierSelectDialog extends StatefulWidget {
  final PosController controller;

  const CashierSelectDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, PosController controller) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CashierSelectDialog(controller: controller),
    );
  }

  @override
  State<CashierSelectDialog> createState() => _CashierSelectDialogState();
}

class _CashierSelectDialogState extends State<CashierSelectDialog> {
  PosCashier? _verifyingCashier;
  String _enteredPin = '';
  String? _errorMessage;

  void _onCashierTap(PosCashier cashier) {
    if (cashier.hasPin) {
      setState(() {
        _verifyingCashier = cashier;
        _enteredPin = '';
        _errorMessage = null;
      });
    } else {
      widget.controller.setActiveCashier(cashier);
      Navigator.pop(context);
    }
  }

  void _appendDigit(String digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });
      if (_enteredPin.length == 4 || (_verifyingCashier?.pin != null && _enteredPin.length == _verifyingCashier!.pin!.length)) {
        _submitPin();
      }
    }
  }

  void _backspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _submitPin() {
    if (_verifyingCashier == null) return;
    final expectedPin = _verifyingCashier!.pin ?? '1212';
    if (_enteredPin == expectedPin) {
      widget.controller.setActiveCashier(_verifyingCashier!);
      Navigator.pop(context);
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _enteredPin = '';
      });
    }
  }

  Color _getAvatarColor(int index) {
    final colors = [
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.purple,
      Colors.green,
      Colors.blue,
      Colors.pink,
      Colors.amber.shade800,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final cashiers = widget.controller.cashiers;
    final active = widget.controller.activeCashier;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: _verifyingCashier != null ? _buildPinView() : _buildSelectionView(cashiers, active),
      ),
    );
  }

  Widget _buildSelectionView(List<PosCashier> cashiers, PosCashier? active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.grabFoodBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: AppColors.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Cashier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('Switch active cashier for this shift', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (cashiers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text('No cashiers found. Please check connection to Odoo.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(cashiers.length, (index) {
                  final c = cashiers[index];
                  final isSelected = active?.id == c.id;
                  final avatarColor = _getAvatarColor(index);

                  return InkWell(
                    onTap: () => _onCashierTap(c),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 208,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.grabFoodBg : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: avatarColor.withOpacity(0.15),
                            child: Text(
                              c.initials,
                              style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (c.hasPin) ...[
                                      const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      const Text('PIN', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ] else ...[
                                      Text(isSelected ? 'Active Now' : 'Staff',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade500,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          )),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPinView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                setState(() {
                  _verifyingCashier = null;
                  _enteredPin = '';
                  _errorMessage = null;
                });
              },
            ),
            Text(
              'Enter PIN for ${_verifyingCashier!.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        // PIN dot indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? AppColors.primaryGreen : Colors.grey.shade200,
                border: Border.all(color: isFilled ? AppColors.primaryGreen : Colors.grey.shade400),
              ),
            );
          }),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 20),
        // 3x4 Keypad
        SizedBox(
          width: 260,
          child: Column(
            children: [
              for (var row = 0; row < 3; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var col = 1; col <= 3; col++)
                        _keypadButton('${row * 3 + col}'),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 72, height: 50),
                  _keypadButton('0'),
                  InkWell(
                    onTap: _backspace,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.backspace_outlined, size: 20, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _keypadButton(String digit) {
    return InkWell(
      onTap: () => _appendDigit(digit),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
