import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

class AdminPinDialog extends StatefulWidget {
  final String title;
  final String message;
  final List<String>? allowedPins;

  const AdminPinDialog({
    super.key,
    this.title = 'OTORISASI ADMIN',
    this.message = 'Masukkan PIN Admin untuk membuka pengaturan server Odoo & Database.',
    this.allowedPins,
  });

  static Future<bool> verify(
    BuildContext context, {
    String title = 'OTORISASI ADMIN',
    String message = 'Masukkan PIN Admin untuk membuka pengaturan server Odoo & Database.',
    List<String>? allowedPins,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminPinDialog(
        title: title,
        message: message,
        allowedPins: allowedPins,
      ),
    );
    return result ?? false;
  }

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  String _enteredPin = '';
  String _actualPin = '1234';
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStoredPin();
  }

  Future<void> _loadStoredPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString('admin_pin');
      if (pin != null && pin.isNotEmpty) {
        setState(() => _actualPin = pin);
      }
    } catch (_) {}
  }

  List<String> get _allValidPins {
    final list = <String>{_actualPin, '1234'};
    if (widget.allowedPins != null) {
      list.addAll(widget.allowedPins!.where((p) => p.isNotEmpty));
    }
    return list.toList();
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _isError = false;
        _enteredPin += digit;
      });

      if (_allValidPins.contains(_enteredPin)) {
        Navigator.pop(context, true);
        return;
      }

      if (_enteredPin.length >= 6) {
        _validate();
      } else if (_enteredPin.length == _actualPin.length && _enteredPin.length >= 4) {
        // If length reached and it's not valid yet, only trigger error if no valid pin has longer length
        final maxValidLength = _allValidPins.fold<int>(4, (max, p) => p.length > max ? p.length : max);
        if (_enteredPin.length >= maxValidLength) {
          _validate();
        }
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _isError = false;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _isError = false;
      _enteredPin = '';
    });
  }

  void _validate() {
    if (_allValidPins.contains(_enteredPin)) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isError = true;
        _errorMessage = 'PIN Salah! Silakan coba lagi.';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: Colors.amber),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // PIN Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_actualPin.length, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? Colors.red
                          : (isFilled ? AppColors.primaryGreen : Colors.grey.shade300),
                      border: Border.all(
                        color: _isError ? Colors.red : (isFilled ? AppColors.primaryGreen : Colors.grey.shade400),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),

              if (_isError) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ] else
                const SizedBox(height: 22),

              // Numeric Keypad
              SizedBox(
                width: 260,
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    const SizedBox(height: 10),
                    _buildRow(['4', '5', '6']),
                    const SizedBox(height: 10),
                    _buildRow(['7', '8', '9']),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton('C', _onClear, color: Colors.orange.shade700),
                        _buildKey('0'),
                        _buildActionButton('⌫', _onBackspace, color: Colors.grey.shade800),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String digit) {
    return SizedBox(
      width: 72,
      height: 52,
      child: ElevatedButton(
        onPressed: () => _onKeyPress(digit),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed, {required Color color}) {
    return SizedBox(
      width: 72,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
