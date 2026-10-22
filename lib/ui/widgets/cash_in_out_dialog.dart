import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/odoo_client.dart';
import '../../data/services/printer/printer_service.dart';
import '../../data/services/printer/printer_settings.dart';
import '../../logic/pos_controller.dart';
import 'touch_numpad.dart';

class CashInOutDialog extends StatefulWidget {
  final OdooClient odooClient;
  final PosController controller;
  final PrinterService printerService;
  final String initialType;

  const CashInOutDialog({
    super.key,
    required this.odooClient,
    required this.controller,
    required this.printerService,
    this.initialType = 'out',
  });

  static Future<bool?> show(
    BuildContext context,
    OdooClient odooClient,
    PosController controller,
    PrinterService printerService, {
    String initialType = 'out',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CashInOutDialog(
        odooClient: odooClient,
        controller: controller,
        printerService: printerService,
        initialType: initialType,
      ),
    );
  }

  @override
  State<CashInOutDialog> createState() => _CashInOutDialogState();
}

class _CashInOutDialogState extends State<CashInOutDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _reasonController = TextEditingController();

  late String _type; // 'out' (Cash Out) or 'in' (Cash In)
  int _amount = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  final _quickAmounts = const [10000, 20000, 50000, 100000];
  final _quickReasonsOut = const ['Beli Es Batu', 'Beli Galon Air', 'Beli Plastik/Cup', 'Uang Kembalian', 'Operasional'];
  final _quickReasonsIn = const ['Modal Tambahan', 'Setoran Kas', 'Pengembalian Belanja'];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _onKeypadPress(String key) {
    final str = _amount.toString();
    if (str == '0') {
      setState(() => _amount = int.tryParse(key) ?? 0);
    } else {
      if (str.length < 9) {
        setState(() => _amount = int.tryParse('$str$key') ?? _amount);
      }
    }
  }

  void _onKeypadBackspace() {
    final str = _amount.toString();
    if (str.length <= 1) {
      setState(() => _amount = 0);
    } else {
      setState(() => _amount = int.tryParse(str.substring(0, str.length - 1)) ?? 0);
    }
  }

  void _onKeypadClear() {
    setState(() => _amount = 0);
  }

  void _onKeypadAdd(int add) {
    setState(() => _amount += add);
  }

  Future<void> _submit() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari Rp 0'), backgroundColor: Colors.orange),
      );
      return;
    }

    final reason = _reasonController.text.trim().isEmpty
        ? (_type == 'out' ? 'Pengeluaran Kasir' : 'Pemasukan Kasir')
        : _reasonController.text.trim();

    setState(() => _isSubmitting = true);
    final cashierName = widget.controller.activeCashier?.name ?? 'Cashier';

    try {
      // 1. Submit to Odoo 19 pos.session
      await widget.odooClient.submitCashInOut(
        type: _type,
        amount: _amount.toDouble(),
        reason: reason,
        cashier: widget.controller.activeCashier,
      );

      // 2. Print physical drawer slip / voucher if printer active
      Map<String, dynamic>? printRes;
      if (widget.printerService.settings.connectionType != PrinterConnectionType.disabled) {
        printRes = await widget.printerService.printCashMoveSlip(
          type: _type,
          amount: _amount,
          reason: reason,
          cashierName: cashierName,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        final label = _type == 'out' ? 'Cash Out' : 'Cash In';
        final printOk = printRes == null || printRes['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printOk
                  ? '✅ $label ${_currency.format(_amount)} dicatat di Odoo & slip dicetak.'
                  : '⚠️ $label ${_currency.format(_amount)} dicatat di Odoo, tapi cetak slip gagal: ${printRes['message']}',
            ),
            backgroundColor: printOk ? Colors.green : Colors.orange.shade800,
            duration: Duration(seconds: printOk ? 3 : 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat mutasi kas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashierName = widget.controller.activeCashier?.name ?? 'Cashier';
    final isOut = _type == 'out';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOut ? Colors.amber.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.payments_outlined,
                      color: isOut ? Colors.amber.shade800 : Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOut ? 'Cash Out (Tarik Kas Kecil)' : 'Cash In (Setor Kas)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Kasir: $cashierName • ${widget.odooClient.activeSessionName ?? "Session"}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Two-column layout for Tablet: Left details, Right Touch Numpad
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN: Controls & Reason
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mode Segmented Switch
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _type = 'out'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isOut ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: isOut ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
                                    ),
                                    child: Text(
                                      'Tarik Kas (Cash Out)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isOut ? Colors.amber.shade900 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _type = 'in'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: !isOut ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: !isOut ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
                                    ),
                                    child: Text(
                                      'Setor Kas (Cash In)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !isOut ? Colors.green.shade800 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Large Display Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isOut ? Colors.amber.shade50.withOpacity(0.5) : Colors.green.shade50.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isOut ? Colors.amber.shade300 : Colors.green.shade300, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _currency.format(_amount),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isOut ? Colors.amber.shade900 : Colors.green.shade900,
                                ),
                              ),
                              if (_amount > 0)
                                ActionChip(
                                  label: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.grey.shade200,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _onKeypadClear,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Quick Reason Chips
                        Text(
                          'Pilih Alasan Cepat:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: (isOut ? _quickReasonsOut : _quickReasonsIn).map((r) {
                            final isSelected = _reasonController.text == r;
                            return ActionChip(
                              label: Text(r, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              backgroundColor: isSelected ? (isOut ? Colors.amber.shade100 : Colors.green.shade100) : Colors.grey.shade100,
                              side: BorderSide(color: isSelected ? (isOut ? Colors.amber.shade400 : Colors.green.shade400) : Colors.grey.shade300),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _reasonController.text = r;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Reason Input
                        TextField(
                          controller: _reasonController,
                          decoration: InputDecoration(
                            hintText: isOut ? 'Alasan lain (e.g. Beli Es Batu)...' : 'Alasan lain (e.g. Modal Tambahan)...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Submit Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                            label: Text(
                              _isSubmitting
                                  ? 'Menyimpan ke Odoo...'
                                  : 'Simpan ${isOut ? "Cash Out" : "Cash In"} & Cetak Slip',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOut ? Colors.amber.shade900 : Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 18),

                  // RIGHT COLUMN: Touch Numpad for Tablet
                  SizedBox(
                    width: 290,
                    child: TouchNumpad(
                      onKeyPress: _onKeypadPress,
                      onBackspace: _onKeypadBackspace,
                      onClear: _onKeypadClear,
                      quickAddAmounts: _quickAmounts,
                      onQuickAdd: _onKeypadAdd,
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
