import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic/pos_controller.dart';
import '../../ui/core/app_colors.dart';
import '../../ui/widgets/cashier_select_dialog.dart';
import '../../ui/widgets/touch_numpad.dart';

class SessionOpenView extends StatelessWidget {
  final PosController controller;
  final double openingCash;
  final double suggestedOpeningCash;
  final bool isLoadingOpeningCash;
  final bool isSubmitting;
  final String? errorMessage;
  final TextEditingController notesController;
  final ValueChanged<String> onKeypadPress;
  final VoidCallback onKeypadBackspace;
  final VoidCallback onKeypadClear;
  final ValueChanged<int> onKeypadAdd;
  final VoidCallback onApplySuggested;
  final VoidCallback onSubmitOpen;
  final VoidCallback onCashierChanged;

  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  const SessionOpenView({
    super.key,
    required this.controller,
    required this.openingCash,
    required this.suggestedOpeningCash,
    required this.isLoadingOpeningCash,
    required this.isSubmitting,
    required this.errorMessage,
    required this.notesController,
    required this.onKeypadPress,
    required this.onKeypadBackspace,
    required this.onKeypadClear,
    required this.onKeypadAdd,
    required this.onApplySuggested,
    required this.onSubmitOpen,
    required this.onCashierChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeCashier = controller.activeCashier;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Cashier & Notes
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  await CashierSelectDialog.show(context, controller);
                  onCashierChanged();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 20, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pilih Kasir Bertugas:', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                              Text(
                                activeCashier?.name ?? "Pilih Kasir",
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Ganti Kasir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                            SizedBox(width: 4),
                            Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.primaryGreen),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.cashiers.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: controller.cashiers.map((c) {
                    final isSelected = c.id == activeCashier?.id;
                    return ChoiceChip(
                      label: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryGreen,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) async {
                        if (c.hasPin) {
                          await CashierSelectDialog.show(context, controller);
                        } else {
                          controller.setActiveCashier(c);
                        }
                        onCashierChanged();
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),

              // Opening Float Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Modal Awal Laci (Opening Cash Float)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  if (isLoadingOpeningCash)
                    const Row(
                      children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryGreen)),
                        SizedBox(width: 6),
                        Text('Memuat saldo Odoo...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currency.format(openingCash),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (suggestedOpeningCash > 0 && openingCash != suggestedOpeningCash)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.history_rounded, size: 14, color: AppColors.primaryGreen),
                              label: Text(
                                'Saldo Kemarin (${_currency.format(suggestedOpeningCash)})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                              ),
                              backgroundColor: Colors.green.shade50,
                              visualDensity: VisualDensity.compact,
                              onPressed: onApplySuggested,
                            ),
                          ),
                        if (openingCash > 0)
                          ActionChip(
                            label: const Text('Reset 0', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.grey.shade200,
                            visualDensity: VisualDensity.compact,
                            onPressed: onKeypadClear,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (suggestedOpeningCash > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Otomatis terisi dari saldo penutupan sesi sebelumnya: ${_currency.format(suggestedOpeningCash)}',
                        style: TextStyle(fontSize: 11.5, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              const Text(
                'Catatan Pembukaan (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'e.g. Opened from Arawali Store POS',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmitOpen,
                  icon: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    isSubmitting ? 'Membuka Sesi di Odoo...' : 'Buka Register & Mulai Jualan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 18),

        // RIGHT COLUMN: Touch Numpad
        SizedBox(
          width: 290,
          child: TouchNumpad(
            onKeyPress: onKeypadPress,
            onBackspace: onKeypadBackspace,
            onClear: onKeypadClear,
            quickAddAmounts: const [50000, 100000, 200000, 500000],
            onQuickAdd: onKeypadAdd,
          ),
        ),
      ],
    );
  }
}
