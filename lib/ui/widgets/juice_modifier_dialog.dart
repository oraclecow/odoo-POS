import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/juice_product.dart';
import '../../data/models/modifier.dart';
import '../core/app_colors.dart';

class JuiceModifierDialog extends StatefulWidget {
  final JuiceProduct product;
  final List<AddOnOption> availableAddOns;
  final Function(SelectedModifiers modifiers) onConfirm;

  const JuiceModifierDialog({
    super.key,
    required this.product,
    required this.availableAddOns,
    required this.onConfirm,
  });

  @override
  State<JuiceModifierDialog> createState() => _JuiceModifierDialogState();
}

class _JuiceModifierDialogState extends State<JuiceModifierDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  String _selectedSugar = 'Normal';
  String _selectedIce = 'Normal';
  String _selectedSkm = 'Normal';
  final Set<AddOnOption> _selectedAddOns = {};

  final _sugarOptions = const ['Normal', 'Less Sugar', 'No Sugar', 'Extra Sugar', 'Stevia'];
  final _iceOptions = const ['Normal', 'Less Ice', 'No Ice', 'Extra Ice'];
  final _skmOptions = const ['Normal', 'Less SKM', 'No SKM', 'Extra SKM'];

  int get _calculatedTotal {
    final addOnTotal = _selectedAddOns.fold(0, (sum, item) => sum + item.extraPrice);
    return widget.product.price + addOnTotal;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Product Name | Price + Close X
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.product.name.toUpperCase()} | ${_currency.format(widget.product.price)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.divider),

              // Scrollable Options Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('GULA'),
                      _buildPillSelector(
                        options: _sugarOptions,
                        selected: _selectedSugar,
                        onSelected: (val) => setState(() => _selectedSugar = val),
                      ),
                      const SizedBox(height: 12),

                      _buildSectionTitle('ES'),
                      _buildPillSelector(
                        options: _iceOptions,
                        selected: _selectedIce,
                        onSelected: (val) => setState(() => _selectedIce = val),
                      ),
                      const SizedBox(height: 12),

                      _buildSectionTitle('SKM'),
                      _buildPillSelector(
                        options: _skmOptions,
                        selected: _selectedSkm,
                        onSelected: (val) => setState(() => _selectedSkm = val),
                      ),
                      const SizedBox(height: 12),

                      _buildSectionTitle('ADD-ON'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.availableAddOns.map((addon) {
                          final isSelected = _selectedAddOns.contains(addon);
                          return FilterChip(
                            label: Text(
                              '${addon.name} (+${_currency.format(addon.extraPrice)})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.accentPurple,
                            backgroundColor: Colors.grey.shade100,
                            checkmarkColor: Colors.white,
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedAddOns.add(addon);
                                } else {
                                  _selectedAddOns.remove(addon);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Discard',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onConfirm(SelectedModifiers(
                          sugar: _selectedSugar,
                          ice: _selectedIce,
                          skm: _selectedSkm,
                          addOns: _selectedAddOns.toList(),
                        ));
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Add • ${_currency.format(_calculatedTotal)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPillSelector({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((option) {
        final isSelected = option == selected;
        return ChoiceChip(
          label: Text(option),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
          selected: isSelected,
          selectedColor: AppColors.accentPurple,
          backgroundColor: Colors.grey.shade100,
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => onSelected(option),
        );
      }).toList(),
    );
  }
}
