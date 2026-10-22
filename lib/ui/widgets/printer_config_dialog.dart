import 'package:flutter/material.dart';
import '../../data/services/printer/printer_service.dart';
import '../../data/services/printer/printer_settings.dart';
import '../core/app_colors.dart';

class PrinterConfigDialog extends StatefulWidget {
  final PrinterService printerService;

  const PrinterConfigDialog({super.key, required this.printerService});

  static Future<void> show(BuildContext context, PrinterService printerService) async {
    await showDialog(
      context: context,
      builder: (_) => PrinterConfigDialog(printerService: printerService),
    );
  }

  @override
  State<PrinterConfigDialog> createState() => _PrinterConfigDialogState();
}

class _PrinterConfigDialogState extends State<PrinterConfigDialog> {
  late String _activePresetId;
  late PrinterConnectionType _connectionType;
  late TextEditingController _windowsPrinterController;
  late TextEditingController _eposUrlController;
  late PrinterPaperWidth _paperWidth;
  late bool _autoCutter;
  late bool _autoPrintReceipt;
  late bool _autoPrintKitchen;

  bool _isTesting = false;
  String? _testResult;
  bool _isTestSuccess = false;

  @override
  void initState() {
    super.initState();
    final s = widget.printerService.settings;
    _activePresetId = s.activePresetId;
    _connectionType = s.connectionType;

    _windowsPrinterController = TextEditingController(text: s.windowsPrinterName);
    _eposUrlController = TextEditingController(text: s.eposEndpoint);
    _paperWidth = s.paperWidth;
    _autoCutter = s.autoCutter;
    _autoPrintReceipt = s.autoPrintReceipt;
    _autoPrintKitchen = s.autoPrintKitchen;
  }

  @override
  void dispose() {
    _windowsPrinterController.dispose();
    _eposUrlController.dispose();
    super.dispose();
  }

  void _applyPreset(PrinterPreset preset) {
    setState(() {
      _activePresetId = preset.id;
      _connectionType = preset.type;
      _paperWidth = preset.width;
      _autoCutter = preset.cutter;
      if (preset.type == PrinterConnectionType.epos) {
        _eposUrlController.text = preset.eposUrl;
      }
      _testResult = null;
    });

    final s = widget.printerService.settings;
    s.applyPreset(preset);
    s.windowsPrinterName = _windowsPrinterController.text.trim();
    s.eposEndpoint = _eposUrlController.text.trim();
    s.autoPrintReceipt = _autoPrintReceipt;
    s.autoPrintKitchen = _autoPrintKitchen;
    s.save();
    widget.printerService.notifyUpdated();
  }

  void _saveSettings() {
    final s = widget.printerService.settings;
    s.activePresetId = _activePresetId;
    s.connectionType = _connectionType;
    s.windowsPrinterName = _windowsPrinterController.text.trim().isEmpty
        ? '58mm Series Printer'
        : _windowsPrinterController.text.trim();
    s.eposEndpoint = _eposUrlController.text.trim().isEmpty
        ? 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer'
        : _eposUrlController.text.trim();
    s.paperWidth = _paperWidth;
    s.autoCutter = _autoCutter;
    s.autoPrintReceipt = _autoPrintReceipt;
    s.autoPrintKitchen = _autoPrintKitchen;
    s.save();
    widget.printerService.notifyUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Active printer: ${s.activeBadgeName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _runTestPrint() async {
    final s = widget.printerService.settings;
    s.activePresetId = _activePresetId;
    s.connectionType = _connectionType;
    s.windowsPrinterName = _windowsPrinterController.text.trim().isEmpty
        ? '58mm Series Printer'
        : _windowsPrinterController.text.trim();
    s.eposEndpoint = _eposUrlController.text.trim().isEmpty
        ? 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer'
        : _eposUrlController.text.trim();
    s.paperWidth = _paperWidth;
    s.autoCutter = _autoCutter;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await widget.printerService.testPrint();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isTestSuccess = res['success'] == true;
        _testResult = res['message'] ??
            (res['success'] == true
                ? 'Test receipt sent successfully!'
                : 'Failed to print test receipt.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.printerService.settings;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print_rounded, color: AppColors.primaryGreen, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'CASHIER PRINTER SETTINGS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _connectionType == PrinterConnectionType.disabled
                              ? Colors.grey.shade200
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          s.activeBadgeName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _connectionType == PrinterConnectionType.disabled
                                ? Colors.grey.shade700
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 6),

              // 1. Presets Selection (USB Local vs COB Remote vs Disabled)
              const Text(
                'Select Print Mode:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),

              Column(
                children: PrinterPreset.values.map((preset) {
                  final isSelected = _activePresetId == preset.id;
                  IconData icon;
                  switch (preset.type) {
                    case PrinterConnectionType.usb:
                      icon = Icons.usb_rounded;
                      break;
                    case PrinterConnectionType.epos:
                      icon = Icons.cloud_done_rounded;
                      break;
                    default:
                      icon = Icons.print_disabled_rounded;
                      break;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _applyPreset(preset),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryGreen : AppColors.border,
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 22, color: isSelected ? AppColors.primaryGreen : Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    preset.subtitle,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 20)
                            else
                              Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 2. Active Mode Details
              if (_connectionType == PrinterConnectionType.usb) ...[
                const SizedBox(height: 12),
                const Text(
                  'Local Windows Spooler Configuration:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _windowsPrinterController,
                  decoration: InputDecoration(
                    labelText: 'Windows Printer Name',
                    hintText: '58mm Series Printer',
                    helperText: 'Direct RAW ESC/POS via winspool.drv on this machine',
                    helperStyle: TextStyle(fontSize: 11, color: Colors.green.shade800),
                    prefixIcon: const Icon(Icons.print_outlined),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final defPrinter = widget.printerService.getDefaultPrinterName();
                    if (defPrinter == null || defPrinter.isEmpty) return const SizedBox(height: 6);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() {
                            _windowsPrinterController.text = defPrinter;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'Detected Windows Default: "$defPrinter" (Click to use)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use when running on COB or any PC directly connected to the printer via USB. Format: 32 columns, no autocutter.',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_connectionType == PrinterConnectionType.epos) ...[
                const SizedBox(height: 12),
                const Text(
                  'Remote COB Network Printer Configuration:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _eposUrlController,
                  decoration: InputDecoration(
                    labelText: 'COB ePOS Endpoint URL',
                    hintText: 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer',
                    helperText: 'Sends print jobs across LAN to the 58mm printer on COB',
                    helperStyle: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                    prefixIcon: const Icon(Icons.cloud_outlined),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use when running on Kasir 2 or another PC. Print jobs route across the LAN to the 58mm printer plugged into COB.',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(color: AppColors.divider),

              // Auto Print Toggles
              SwitchListTile(
                title: const Text('Auto-print customer receipt after checkout', style: TextStyle(fontSize: 12.5)),
                value: _autoPrintReceipt,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _autoPrintReceipt = v),
              ),
              SwitchListTile(
                title: const Text('Auto-print kitchen / barista ticket', style: TextStyle(fontSize: 12.5)),
                value: _autoPrintKitchen,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _autoPrintKitchen = v),
              ),

              const SizedBox(height: 10),

              // Test Result Box
              if (_testResult != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _isTestSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isTestSuccess ? Colors.green.shade300 : Colors.red.shade300),
                  ),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isTestSuccess ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ),

              // Bottom Actions
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _runTestPrint,
                    icon: _isTesting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Test Print Receipt'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Save & Close', style: TextStyle(fontWeight: FontWeight.bold)),
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
