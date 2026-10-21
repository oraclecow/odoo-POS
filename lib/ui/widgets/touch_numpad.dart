import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';

class TouchNumpad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final List<int>? quickAddAmounts;
  final ValueChanged<int>? onQuickAdd;
  final VoidCallback? onExact;
  final String? exactLabel;
  final bool showZeroShortcuts;
  final Widget? customActionKey;
  final bool showCornerKey;

  const TouchNumpad({
    super.key,
    required this.onKeyPress,
    required this.onBackspace,
    required this.onClear,
    this.quickAddAmounts,
    this.onQuickAdd,
    this.onExact,
    this.exactLabel,
    this.showZeroShortcuts = true,
    this.customActionKey,
    this.showCornerKey = false,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick add presets on top
          if (quickAddAmounts != null && quickAddAmounts!.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (onExact != null)
                  ActionChip(
                    label: Text(exactLabel ?? 'Uang Pas', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.green.shade50,
                    side: BorderSide(color: Colors.green.shade300),
                    visualDensity: VisualDensity.compact,
                    onPressed: onExact,
                  ),
                ...quickAddAmounts!.map((amt) {
                  final label = '+${currency.format(amt).replaceAll("Rp ", "")}';
                  return ActionChip(
                    label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQuickAdd?.call(amt),
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // 3x4 Touch Keypad Grid
          Row(
            children: [
              _buildKey('1'),
              const SizedBox(width: 8),
              _buildKey('2'),
              const SizedBox(width: 8),
              _buildKey('3'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKey('4'),
              const SizedBox(width: 8),
              _buildKey('5'),
              const SizedBox(width: 8),
              _buildKey('6'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKey('7'),
              const SizedBox(width: 8),
              _buildKey('8'),
              const SizedBox(width: 8),
              _buildKey('9'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildActionKey(
                label: 'C',
                color: Colors.red.shade50,
                textColor: Colors.red.shade700,
                onTap: onClear,
              ),
              const SizedBox(width: 8),
              _buildKey('0'),
              const SizedBox(width: 8),
              _buildActionKey(
                icon: Icons.backspace_outlined,
                color: Colors.amber.shade50,
                textColor: Colors.amber.shade900,
                onTap: onBackspace,
              ),
            ],
          ),
          if (showZeroShortcuts) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildKey('00'),
                const SizedBox(width: 8),
                _buildKey('000'),
                const SizedBox(width: 8),
                if (customActionKey != null)
                  Expanded(child: customActionKey!)
                else if (showCornerKey && onExact != null)
                  _buildActionKey(
                    label: exactLabel ?? 'Pas',
                    color: Colors.green.shade50,
                    textColor: Colors.green.shade800,
                    onTap: onExact!,
                  )
                else
                  const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKey(String val) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 0.8,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onKeyPress(val),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              val,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    String? label,
    IconData? icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        elevation: 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: textColor.withOpacity(0.3)),
            ),
            child: icon != null
                ? Icon(icon, color: textColor, size: 20)
                : Text(
                    label!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
