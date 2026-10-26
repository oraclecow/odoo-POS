import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../logic/pos_controller.dart';
import '../../data/services/odoo_client.dart';
import '../../data/services/printer/printer_service.dart';
import '../../modules/pos_session/session_open_view.dart';
import '../../modules/pos_session/session_close_view.dart';
import '../core/app_colors.dart';
import 'cash_in_out_dialog.dart';

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
  final _notesController = TextEditingController(text: 'Opened from AraPOS');

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
      final notes = _notesController.text.trim().isEmpty
          ? 'Opened from AraPOS'
          : _notesController.text.trim();

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

  // --- PRINT SESSION CLOSE SLIP ---
  Future<void> _handlePrintZReport() async {
    if (_closingData == null) return;
    final PrinterService printer = widget.printerService ?? ref.read(printerServiceProvider);
    final diff = _countedCash - _closingData!.expectedCash;

    final res = await printer.printClosingZReport(
      sessionName: widget.controller.activeSessionName ?? '#${widget.controller.activeSessionId}',
      cashierName: widget.controller.activeCashier?.name,
      closingData: _closingData!,
      countedCash: _countedCash,
      cashDifference: diff,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Laporan Penutupan Kasir dikirim ke printer.'),
          backgroundColor: res['success'] == true ? AppColors.primaryGreen : Colors.orange.shade800,
        ),
      );
    }
  }

  // --- CLOSE REGISTER & POST TO ODOO ---
  Future<void> _handleCloseSession({bool forceClose = false}) async {
    if (_closingData == null) return;

    final diff = _countedCash - _closingData!.expectedCash;

    // If difference is non-zero, ask confirmation (skip if already force closing)
    if (diff != 0 && !forceClose) {
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

      // 1. Submit close to Odoo ORM (with automatic or explicit force close support)
      final closeResult = await widget.controller.closeSession(
        countedCash: _countedCash,
        forceClose: forceClose,
      );

      // 2. Auto-print Session Close report slip
      Map<String, dynamic>? printRes;
      try {
        final PrinterService printer = widget.printerService ?? ref.read(printerServiceProvider);
        printRes = await printer.printClosingZReport(
          sessionName: sessionName,
          cashierName: widget.controller.activeCashier?.name,
          closingData: _closingData!,
          countedCash: _countedCash,
          cashDifference: diff,
        );
      } catch (pe) {
        debugPrint('Auto Session Close print error: $pe');
        printRes = {'success': false, 'message': pe.toString()};
      }

      if (mounted) {
        Navigator.pop(context, true);
        final printOk = printRes != null && printRes['success'] == true;
        final extraNote = closeResult.autoForceClosed && (closeResult.amountBalanced != null && closeResult.amountBalanced != 0)
            ? ' (Force close selisih pembukuan ${_currency.format(closeResult.amountBalanced!.abs())})'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: printOk ? AppColors.primaryGreen : Colors.orange.shade800,
            duration: Duration(seconds: printOk ? 3 : 6),
            content: Text(
              printOk
                  ? 'Sesi $sessionName berhasil ditutup$extraNote dan Laporan Penutupan Kasir telah dicetak!'
                  : 'Sesi $sessionName ditutup di Odoo$extraNote, namun cetak Laporan gagal: ${printRes?['message'] ?? 'Printer tidak merespon'}. Anda dapat mencetak ulang dari menu.',
            ),
          ),
        );
      }
    } on PosDiscrepancyException catch (de) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Selisih pembukuan Odoo terdeteksi: ${_currency.format(de.amountToBalance.abs())}. Silakan konfirmasi Tutup Paksa.';
        });
        _promptAcknowledgeDiscrepancy(de);
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

  Future<void> _promptAcknowledgeDiscrepancy(PosDiscrepancyException de) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 26),
            const SizedBox(width: 8),
            const Text('Acknowledge Selisih Pembukuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Odoo mendeteksi perbedaan pembukuan jurnal move saat penutupan register:',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                'Selisih: ${_currency.format(de.amountToBalance)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Penyebab umum: Pembulatan diskon atau selisih tarif pajak multi-item.\n\nApakah Anda ingin mengonfirmasi (acknowledge) dan menutup paksa (force close) sesi ini sekarang dari kasir tanpa perlu membuka Odoo web?',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal / Periksa Lagi'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.flash_on_rounded, size: 16),
            label: const Text('Acknowledge & Force Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _handleCloseSession(forceClose: true);
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
                // --- MODE A: OPEN REGISTER (MODULAR SESSION OPEN VIEW) ---
                SessionOpenView(
                  controller: widget.controller,
                  openingCash: _openingCash,
                  suggestedOpeningCash: _suggestedOpeningCash,
                  isLoadingOpeningCash: _isLoadingOpeningCash,
                  isSubmitting: _isSubmitting,
                  errorMessage: _errorMessage,
                  notesController: _notesController,
                  onCashierChanged: () => setState(() {}),
                  onApplySuggested: () => setState(() => _openingCash = _suggestedOpeningCash),
                  onKeypadPress: _onOpeningKeypadPress,
                  onKeypadBackspace: _onOpeningKeypadBackspace,
                  onKeypadClear: _onOpeningKeypadClear,
                  onKeypadAdd: _onOpeningKeypadAdd,
                  onSubmitOpen: _handleOpenSession,
                )
              else
                // --- MODE B: CLOSE REGISTER (MODULAR SESSION CLOSE VIEW) ---
                SessionCloseView(
                  controller: widget.controller,
                  closingData: _closingData,
                  isLoadingClosingData: _isLoadingClosingData,
                  closingDataError: _closingDataError,
                  countedCash: _countedCash,
                  isSubmitting: _isSubmitting,
                  errorMessage: _errorMessage,
                  onRetryLoad: _loadClosingData,
                  onOpenCashOut: () => _handleOpenCashInOut(initialType: 'out'),
                  onPrintZReport: _handlePrintZReport,
                  onKeypadPress: _onClosingKeypadPress,
                  onKeypadBackspace: _onClosingKeypadBackspace,
                  onKeypadClear: _onClosingKeypadClear,
                  onKeypadAdd: _onClosingKeypadAdd,
                  onSetExactCash: _onClosingExact,
                  onSubmitClose: _handleCloseSession,
                  onForceClose: () => _handleCloseSession(forceClose: true),
                ),
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
                      ? 'Rekonsiliasi kas & cetak Laporan Penutupan Kasir Odoo 19'
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
}
