import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/odoo_client.dart';
import '../../logic/pos_controller.dart';
import '../../ui/core/app_colors.dart';
import '../../ui/widgets/touch_numpad.dart';

class SessionCloseView extends StatelessWidget {
  final PosController controller;
  final PosClosingControlData? closingData;
  final bool isLoadingClosingData;
  final String? closingDataError;
  final double countedCash;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onRetryLoad;
  final VoidCallback onOpenCashOut;
  final VoidCallback onPrintZReport;
  final VoidCallback onSubmitClose;
  final ValueChanged<String> onKeypadPress;
  final VoidCallback onKeypadBackspace;
  final VoidCallback onKeypadClear;
  final ValueChanged<int> onKeypadAdd;
  final VoidCallback onSetExactCash;

  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  const SessionCloseView({
    super.key,
    required this.controller,
    required this.closingData,
    required this.isLoadingClosingData,
    required this.closingDataError,
    required this.countedCash,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onRetryLoad,
    required this.onOpenCashOut,
    required this.onPrintZReport,
    required this.onSubmitClose,
    required this.onKeypadPress,
    required this.onKeypadBackspace,
    required this.onKeypadClear,
    required this.onKeypadAdd,
    required this.onSetExactCash,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingClosingData) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Mengambil data rekonsiliasi kas dari Odoo 19...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (closingDataError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('Gagal Memuat Data Sesi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 6),
            Text(closingDataError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetryLoad,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final data = closingData!;
    final diff = countedCash - data.expectedCash;
    final allowCashInOut = controller.activeProfile.guardrails.allowCashInOut;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Details, Drawer Cash Summary, and Actions
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Session & Sales Overview Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.activeSessionName ?? '#${controller.activeSessionId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Kasir: ${controller.activeCashier?.name ?? "Staff"}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: const Text('Aktif (Open)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                        ),
                      ],
                    ),
                    const Divider(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Nota', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                              Text('${data.orderCount} Nota', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Omset (Gross)', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                              Text(_currency.format(data.totalSales), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primaryGreen)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. Non-Cash Breakdown (QRIS / Online)
              if (data.nonCashMethods.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.credit_card_rounded, size: 14, color: Colors.blue.shade800),
                          const SizedBox(width: 6),
                          Text(
                            'Non-Tunai / Bank / Online',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...data.nonCashMethods.map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${m.name} (${m.number})', style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                                Text(_currency.format(m.amount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 3. Cash Control Drawer Details Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 14, color: Colors.amber.shade900),
                            const SizedBox(width: 6),
                            Text(
                              'Kontrol Uang Kas Laci (Cash Control)',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                        if (allowCashInOut)
                          InkWell(
                            onTap: isSubmitting ? null : onOpenCashOut,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.payments_outlined, size: 12, color: Colors.amber.shade900),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tarik / Setor Kas',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildRowDetail('Modal Awal (Opening Float)', _currency.format(data.openingCash)),
                    _buildRowDetail('(+) Penjualan Tunai (Cash)', _currency.format(data.cashPayments)),
                    if (data.cashMovesTotal != 0)
                      _buildRowDetail(
                        '(+/-) Mutasi Kas (Tarik/Setor)',
                        '${data.cashMovesTotal >= 0 ? '+' : ''}${_currency.format(data.cashMovesTotal)}',
                      ),
                    const Divider(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '(=) Kas Seharusnya di Laci:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        ),
                        Text(
                          _currency.format(data.expectedCash),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // 4. Action Buttons Bar
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Lanjut Jualan', style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                  if (allowCashInOut) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: isSubmitting ? null : onOpenCashOut,
                        icon: const Icon(Icons.payments_outlined, size: 14),
                        label: const Text('Tarik Kas', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade900,
                          side: BorderSide(color: Colors.amber.shade700),
                          backgroundColor: Colors.amber.shade50.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting ? null : onPrintZReport,
                      icon: const Icon(Icons.print_outlined, size: 14),
                      label: const Text('Cetak Laporan', style: TextStyle(fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo,
                        side: const BorderSide(color: Colors.indigo),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 5. Tutup Register & Validasi
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmitClose,
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_rounded, size: 16),
                  label: Text(
                    isSubmitting ? 'Menutup Register di Odoo...' : 'Tutup Register & Validasi Kas',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // RIGHT COLUMN: Touch Numpad + Counted Cash Box
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TouchNumpad(
                onKeyPress: onKeypadPress,
                onBackspace: onKeypadBackspace,
                onClear: onKeypadClear,
                quickAddAmounts: const [10000, 50000, 100000, 200000],
                onQuickAdd: onKeypadAdd,
                onExact: onSetExactCash,
                exactLabel: 'Uang Pas',
                showCornerKey: false,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Uang Kas Fisik di Laci:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (countedCash != data.expectedCash)
                    ActionChip(
                      label: const Text('Set Pas', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.green.shade50,
                      side: BorderSide(color: Colors.green.shade300),
                      visualDensity: VisualDensity.compact,
                      onPressed: onSetExactCash,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGreen, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currency.format(countedCash),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                    if (countedCash != 0)
                      InkWell(
                        onTap: onKeypadClear,
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _buildDifferenceIndicator(diff),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary)),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDifferenceIndicator(double diff) {
    if (diff == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryGreen, size: 16),
            SizedBox(width: 6),
            Text(
              'Selisih Kas: Rp 0 · Pas (Balanced)',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (diff > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 16),
            const SizedBox(width: 6),
            Text(
              'Selisih Kas: +${_currency.format(diff)} · Lebih (Surplus)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Text(
            'Selisih Kas: -${_currency.format(diff.abs())} · Kurang (Shortage)',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
