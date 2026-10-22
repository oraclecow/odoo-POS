import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/juice_product.dart';
import '../../data/models/modifier.dart';
import '../../data/models/order.dart';
import '../core/app_colors.dart';

class JuiceModifierDialog extends StatefulWidget {
  final JuiceProduct product;
  final List<AddOnOption> availableAddOns;
  final OrderChannelType channelType;
  final Function(SelectedModifiers modifiers) onConfirm;

  const JuiceModifierDialog({
    super.key,
    required this.product,
    required this.availableAddOns,
    this.channelType = OrderChannelType.retail,
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

  int get _basePrice => widget.product.getPriceForChannel(widget.channelType);

  int get _calculatedTotal {
    final addOnTotal = _selectedAddOns.fold(0, (sum, item) => sum + item.extraPrice);
    return _basePrice + addOnTotal;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Product Name | Price + Close X
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.accentPurple, size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${widget.product.name.toUpperCase()} • ${_currency.format(_basePrice)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
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
              const Divider(height: 18, color: AppColors.divider),

              // Side-by-Side 2-Column Options Content for Wide Tablets
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: GULA, ES, SKM
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
                    const SizedBox(width: 16),

                    // RIGHT COLUMN: ADD-ON / TOPPING (ALWAYS VISIBLE SIDE-BY-SIDE)
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('ADD-ON / TOPPING'),
                              if (_selectedAddOns.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPurple.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.accentPurple, width: 0.8),
                                  ),
                                  child: Text(
                                    '${_selectedAddOns.length} dipilih',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentPurple,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: widget.availableAddOns.isEmpty
                                ? Center(
                                    child: Text(
                                      'Tidak ada add-on tersedia',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                    ),
                                  )
                                : Scrollbar(
                                    thumbVisibility: true,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: GridView.builder(
                                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          childAspectRatio: 2.3,
                                        ),
                                        itemCount: widget.availableAddOns.length,
                                        itemBuilder: (context, index) {
                                          final addon = widget.availableAddOns[index];
                                          final isSelected = _selectedAddOns.contains(addon);
                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (isSelected) {
                                                  _selectedAddOns.remove(addon);
                                                } else {
                                                  _selectedAddOns.add(addon);
                                                }
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.accentPurple.withOpacity(0.12)
                                                    : Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AppColors.accentPurple
                                                      : Colors.grey.shade300,
                                                  width: isSelected ? 1.5 : 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isSelected
                                                        ? Icons.check_circle_rounded
                                                        : Icons.radio_button_unchecked_rounded,
                                                    size: 18,
                                                    color: isSelected
                                                        ? AppColors.accentPurple
                                                        : Colors.grey.shade400,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          addon.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: isSelected
                                                                ? FontWeight.w700
                                                                : FontWeight.w600,
                                                            color: isSelected
                                                                ? AppColors.accentPurple
                                                                : AppColors.textPrimary,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '+${_currency.format(addon.extraPrice)}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: isSelected
                                                                ? AppColors.accentPurple
                                                                : AppColors.textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),

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
                      'Batal',
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
                        'Tambah ke Pesanan • ${_currency.format(_calculatedTotal)}',
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
