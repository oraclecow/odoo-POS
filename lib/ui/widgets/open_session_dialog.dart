import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../logic/pos_controller.dart';
import '../../data/services/odoo_client.dart';
import '../../data/services/printer/printer_service.dart';
import '../core/app_colors.dart';
import 'touch_numpad.dart';
import 'cash_in_out_dialog.dart';
import 'cashier_select_dialog.dart';

class OpenSessionDialog extends ConsumerStatefulWidget {
  final PosController controller;
  final PrinterService? printerService;

  const OpenSessionDialog({
    super.key,
    required this.controller,
    this.printerService,
  });

  static Future<bool?> show(
    BuildContext context,
    PosController controller, {
    PrinterService? printerService,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => OpenSessionDialog(
        controller: controller,
        printerService: printerService,
      ),
    );
  }

  @override
  ConsumerState<OpenSessionDialog> createState() => _OpenSessionDialogState();
}

class _OpenSessionDialogState extends ConsumerState<OpenSessionDialog> {
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Opening Mode state
  double _openingCash = 0.0;
  double _suggestedOpeningCash = 0.0;
  bool _isLoadingOpeningCash = false;
  final _notesController = TextEditingController(text: 'Opened from Open Odoo POS');

  // Closing Mode state
  double _countedCash = 0.0;
  PosClosingControlData? _closingData;
  bool _isLoadingClosingData = false;
  String? _closingDataError;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.controller.isSessionOpen) {
      _loadClosingData();
    } else {
      _loadOpeningData();
    }
  }

  Future<void> _loadOpeningData() async {
    setState(() => _isLoadingOpeningCash = true);
    try {
      final expected = await widget.controller.fetchExpectedOpeningCash();
      if (!mounted) return;
      setState(() {
        _isLoadingOpeningCash = false;
        if (expected > 0) {
          _openingCash = expected;
          _suggestedOpeningCash = expected;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOpeningCash = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadClosingData() async {
    setState(() {
      _isLoadingClosingData = true;
      _closingDataError = null;
    });

    try {
      final data = await widget.controller.fetchClosingControlData();
      if (!mounted) return;
      setState(() {
        _closingData = data;
        _isLoadingClosingData = false;
        // Default counted cash to expected drawer cash
        _countedCash = data.expectedCash;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingClosingData = false;
        _closingDataError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // --- TOUCH NUMPAD HANDLERS (OPENING) ---
  void _onOpeningKeypadPress(String key) {
    final str = _openingCash.toInt().toString();
    if (str == '0') {
      setState(() => _openingCash = double.tryParse(key) ?? 0.0);
    } else if (str.length < 9) {
      setState(() => _openingCash = double.tryParse('$str$key') ?? _openingCash);
    }
  }

  void _onOpeningKeypadBackspace() {
    final str = _openingCash.toInt().toString();
    if (str.length <= 1) {
      setState(() => _openingCash = 0.0);
    } else {
      setState(() => _openingCash = double.tryParse(str.substring(0, str.length - 1)) ?? 0.0);
    }
  }

  void _onOpeningKeypadClear() {
    setState(() => _openingCash = 0.0);
  }

  void _onOpeningKeypadAdd(int add) {
    setState(() => _openingCash += add);
  }

  // --- TOUCH NUMPAD HANDLERS (CLOSING) ---
  void _onClosingKeypadPress(String key) {
    final str = _countedCash.toInt().toString();
    if (str == '0') {
      setState(() => _countedCash = double.tryParse(key) ?? 0.0);
    } else if (str.length < 9) {
      setState(() => _countedCash = double.tryParse('$str$key') ?? _countedCash);
    }
  }

  void _onClosingKeypadBackspace() {
    final str = _countedCash.toInt().toString();
    if (str.length <= 1) {
      setState(() => _countedCash = 0.0);
    } else {
      setState(() => _countedCash = double.tryParse(str.substring(0, str.length - 1)) ?? 0.0);
    }
  }

  void _onClosingKeypadClear() {
    setState(() => _countedCash = 0.0);
  }

  void _onClosingKeypadAdd(int add) {
    setState(() => _countedCash += add);
  }

  void _onClosingExact() {
    if (_closingData != null) {
      setState(() => _countedCash = _closingData!.expectedCash);
    }
  }

  // --- OPEN SESSION HANDLER ---
  Future<void> _handleOpenSession() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final notes = _notesController.text.trim().isEmpty ? 'Opened from Open Odoo POS' : _notesController.text.trim();

      final sId = await widget.controller.openSession(
        openingCash: _openingCash,
        notes: notes,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryGreen,
            content: Text('Session #$sId opened successfully with ${_currency.format(_openingCash)}!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // --- CASH IN / CASH OUT HANDLER ---
  Future<void> _handleOpenCashInOut({String initialType = 'out'}) async {
    final OdooClient? client = widget.controller.odooClient ?? ref.read(odooClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Klien Odoo belum siap.')),
      );
      return;
    }

    final PrinterService printer = widget.printerService ?? ref.read(printerServiceProvider);

    final res = await CashInOutDialog.show(
      context,
      client,
      widget.controller,
      printer,
      initialType: initialType,
    );

    if (res == true) {
      await _loadClosingData();
    }
  }

  // --- PRINT Z-REPORT SLIP ---
  Future<void> _handlePrintZReport() async {
    if (_closingData == null) return;
    final PrinterService printer = widget.printerService ?? ref.read(printerServiceProvider);
    final diff = _countedCash - _closingData!.expectedCash;

    final profile = widget.controller.odooClient?.profile;
    final res = await printer.printClosingZReport(
      sessionName: widget.controller.activeSessionName ?? '#${widget.controller.activeSessionId}',
      cashierName: widget.controller.activeCashier?.name,
      closingData: _closingData!,
      countedCash: _countedCash,
      cashDifference: diff,
      storeName: profile?.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim() ?? 'STORE POS',
      customHeader: profile?.receiptHeader,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Z-Report sent to printer.'),
          backgroundColor: res['success'] == true ? AppColors.primaryGreen : Colors.orange.shade800,
        ),
      );
    }
  }

  // --- CLOSE REGISTER & POST TO ODOO ---
  Future<void> _handleCloseSession() async {
    if (_closingData == null) return;

    final diff = _countedCash - _closingData!.expectedCash;

    // If difference is non-zero, ask confirmation
    if (diff != 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              const Text('Konfirmasi Selisih Kas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                diff > 0
                    ? 'Terdapat selisih LEBIH kas sebesar ${_currency.format(diff)}.'
                    : 'Terdapat selisih KURANG kas sebesar ${_currency.format(diff.abs())}.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Kas Seharusnya : ${_currency.format(_closingData!.expectedCash)}\n'
                'Kas Dihitung   : ${_currency.format(_countedCash)}\n\n'
                'Apakah Anda yakin ingin menutup register dengan selisih ini?',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal / Hitung Ulang'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: diff > 0 ? Colors.amber.shade900 : Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Tutup Register'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final sessionName = widget.controller.activeSessionName ?? '#${widget.controller.activeSessionId}';

      // 1. Submit close to Odoo ORM
      await widget.controller.closeSession(countedCash: _countedCash);

      // 2. Auto-print Z-Report slip
      Map<String, dynamic> printRes;
      try {
        final PrinterService printer = widget.printerService ?? ref.read(printerServiceProvider);
        final profile = widget.controller.odooClient?.profile;
        printRes = await printer.printClosingZReport(
          sessionName: sessionName,
          cashierName: widget.controller.activeCashier?.name,
          closingData: _closingData!,
          countedCash: _countedCash,
          cashDifference: diff,
          storeName: profile?.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim() ?? 'STORE POS',
          customHeader: profile?.receiptHeader,
        );
      } catch (pe) {
        debugPrint('Auto Z-report print error: $pe');
        printRes = {'success': false, 'message': pe.toString()};
      }

      if (mounted) {
        Navigator.pop(context, true);
        final printOk = printRes['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: printOk ? AppColors.primaryGreen : Colors.orange.shade800,
            duration: Duration(seconds: printOk ? 3 : 6),
            content: Text(
              printOk
                  ? 'Sesi $sessionName berhasil ditutup dan Laporan Z telah dicetak!'
                  : 'Sesi $sessionName ditutup di Odoo, namun cetak Laporan Z gagal: ${printRes['message'] ?? 'Printer tidak merespon'}. Anda dapat mencetak ulang dari menu.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSessionOpen = widget.controller.isSessionOpen;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isSessionOpen ? 840 : 780,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildDialogHeader(isSessionOpen),
              const SizedBox(height: 12),

              if (!isSessionOpen)
                // --- MODE A: OPEN REGISTER (WITH TOUCH NUMPAD) ---
                _buildOpenRegisterContent()
              else
                // --- MODE B: CLOSE REGISTER (WITH TOUCH NUMPAD) ---
                _buildCloseRegisterContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isSessionOpen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSessionOpen ? Colors.purple.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSessionOpen ? Icons.point_of_sale_rounded : Icons.lock_open_rounded,
                color: isSessionOpen ? Colors.purple.shade700 : Colors.amber.shade900,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSessionOpen ? 'Tutup Register (Close POS Session)' : 'Buka Register (Open POS Session)',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  isSessionOpen
                      ? 'Rekonsiliasi kas & cetak laporan Z Odoo 19'
                      : 'Buka sesi kasir baru di Odoo 19',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // ==========================================
  // MODE A: OPEN REGISTER CONTENT
  // ==========================================
  Widget _buildOpenRegisterContent() {
    final activeCashier = widget.controller.activeCashier;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Cashier & Notes
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cashier Selection Card (Interactive)
              InkWell(
                onTap: () async {
                  await CashierSelectDialog.show(context, widget.controller);
                  setState(() {});
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
              if (widget.controller.cashiers.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.controller.cashiers.map((c) {
                    final isSelected = c.id == activeCashier?.id;
                    return ChoiceChip(
                      label: Text(c.name, style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      )),
                      selected: isSelected,
                      selectedColor: AppColors.primaryGreen,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) async {
                        if (c.hasPin) {
                          await CashierSelectDialog.show(context, widget.controller);
                        } else {
                          widget.controller.setActiveCashier(c);
                        }
                        setState(() {});
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
                  if (_isLoadingOpeningCash)
                    Row(
                      children: const [
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
                      _currency.format(_openingCash),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_suggestedOpeningCash > 0 && _openingCash != _suggestedOpeningCash)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.history_rounded, size: 14, color: AppColors.primaryGreen),
                              label: Text(
                                'Saldo Kemarin (${_currency.format(_suggestedOpeningCash)})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                              ),
                              backgroundColor: Colors.green.shade50,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _openingCash = _suggestedOpeningCash),
                            ),
                          ),
                        if (_openingCash > 0)
                          ActionChip(
                            label: const Text('Reset 0', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.grey.shade200,
                            visualDensity: VisualDensity.compact,
                            onPressed: _onOpeningKeypadClear,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_suggestedOpeningCash > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Otomatis terisi dari saldo penutupan sesi sebelumnya: ${_currency.format(_suggestedOpeningCash)}',
                        style: TextStyle(fontSize: 11.5, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Opening Notes
              const Text(
                'Catatan Pembukaan (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'e.g. Opened from Open Odoo POS',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              if (_errorMessage != null) ...[
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
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                  onPressed: _isSubmitting ? null : _handleOpenSession,
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    _isSubmitting ? 'Membuka Sesi di Odoo...' : 'Buka Register & Mulai Jualan',
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

        // RIGHT COLUMN: Touch Numpad for Tablet
        SizedBox(
          width: 290,
          child: TouchNumpad(
            onKeyPress: _onOpeningKeypadPress,
            onBackspace: _onOpeningKeypadBackspace,
            onClear: _onOpeningKeypadClear,
            quickAddAmounts: const [50000, 100000, 200000, 500000],
            onQuickAdd: _onOpeningKeypadAdd,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MODE B: CLOSE REGISTER CONTENT (ODOO STYLE)
  // ==========================================
  Widget _buildCloseRegisterContent() {
    if (_isLoadingClosingData) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            const Text(
              'Mengambil data rekonsiliasi kas dari Odoo 19...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_closingDataError != null) {
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
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text('Gagal Memuat Data Sesi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 6),
            Text(_closingDataError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadClosingData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final data = _closingData!;
    final diff = _countedCash - data.expectedCash;

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
                              widget.controller.activeSessionName ?? '#${widget.controller.activeSessionId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Kasir: ${widget.controller.activeCashier?.name ?? "Staff"}',
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
                        InkWell(
                          onTap: _isSubmitting ? null : () => _handleOpenCashInOut(initialType: 'out'),
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

              if (_errorMessage != null) ...[
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
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // 4. Action Buttons Bar
              Row(
                children: [
                  // Lanjut Jualan
                  Expanded(
                    flex: 3,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Lanjut Jualan', style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Tarik Kas (Cash Out)
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : () => _handleOpenCashInOut(initialType: 'out'),
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
                  const SizedBox(width: 6),

                  // Cetak Laporan Z
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _handlePrintZReport,
                      icon: const Icon(Icons.print_outlined, size: 14),
                      label: const Text('Cetak Lap. Z', style: TextStyle(fontSize: 11.5)),
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

              // 5. Tutup Register & Validasi (Prominent Full Width Button)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleCloseSession,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_rounded, size: 16),
                  label: Text(
                    _isSubmitting ? 'Menutup Register di Odoo...' : 'Tutup Register & Validasi Kas',
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

        // RIGHT COLUMN: Touch Numpad + Counted Cash Box Directly Below Numpad
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TouchNumpad(
                onKeyPress: _onClosingKeypadPress,
                onBackspace: _onClosingKeypadBackspace,
                onClear: _onClosingKeypadClear,
                quickAddAmounts: const [10000, 50000, 100000, 200000],
                onQuickAdd: _onClosingKeypadAdd,
                onExact: _onClosingExact,
                exactLabel: 'Uang Pas',
                showCornerKey: false,
              ),
              const SizedBox(height: 8),

              // Uang Kas Fisik di Laci (Counted Cash Display)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Uang Kas Fisik di Laci:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (_countedCash != data.expectedCash)
                    ActionChip(
                      label: const Text('Set Pas', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.green.shade50,
                      side: BorderSide(color: Colors.green.shade300),
                      visualDensity: VisualDensity.compact,
                      onPressed: _onClosingExact,
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
                      _currency.format(_countedCash),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                    if (_countedCash != 0)
                      InkWell(
                        onTap: _onClosingKeypadClear,
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Real-time Difference Indicator (Selisih Kas)
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
        child: Row(
          children: const [
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
            SizedBox(width: 6),
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
