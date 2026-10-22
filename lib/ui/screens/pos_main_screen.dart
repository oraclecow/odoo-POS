import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/pos_controller.dart';
import '../../data/services/printer/printer_service.dart';
import '../widgets/order_ticket_panel.dart';
import '../widgets/catalog_panel.dart';
import '../widgets/order_history_panel.dart';
import '../widgets/open_session_dialog.dart';
import '../core/app_colors.dart';

class PosMainScreen extends ConsumerStatefulWidget {
  const PosMainScreen({super.key});

  @override
  ConsumerState<PosMainScreen> createState() => _PosMainScreenState();
}

class _PosMainScreenState extends ConsumerState<PosMainScreen> {
  final StringBuffer _scannerBuffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    super.dispose();
  }

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // If an editable text field is actively focused, let it receive the event directly
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      bool isTextInputFocused = false;
      primaryFocus.context!.visitAncestorElements((element) {
        if (element.widget is EditableText) {
          isTextInputFocused = true;
          return false;
        }
        return true;
      });
      if (isTextInputFocused) {
        return false;
      }
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastKeystrokeTime).inMilliseconds;
    _lastKeystrokeTime = now;

    // Barcode scanner sends rapid keys (< 90ms between chars)
    if (elapsed > 150) {
      _scannerBuffer.clear();
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final code = _scannerBuffer.toString().trim();
      _scannerBuffer.clear();

      if (code.length >= 3) {
        final controller = ref.read(posControllerProvider);
        final matched = controller.handleBarcodeScan(code);
        if (matched != null && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ditambahkan: ${matched.name}'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
        return true;
      }
      return false;
    }

    if (event.character != null && event.character!.isNotEmpty) {
      _scannerBuffer.write(event.character);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(posControllerProvider);
    final odooClient = ref.watch(odooClientProvider);
    final printerService = ref.watch(printerServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Left Panel: Order Cart & Cashier Controls (36% width, ~420dp)
            const SizedBox(
              width: 420,
              child: OrderTicketPanel(),
            ),
            const VerticalDivider(width: 2, thickness: 2, color: AppColors.borderDark),
            // Right Panel: Catalog OR Order History (64% width)
            Expanded(
              child: Column(
                children: [
                  if (!controller.isSessionOpen)
                    Container(
                      width: double.infinity,
                      color: Colors.amber.shade100,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No active POS session in Odoo 19 for ${odooClient.profile.displayName}. Open a session to submit orders.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: const Text('Open Session', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.amber.shade900,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => OpenSessionDialog.show(context, controller),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: controller.activeTab == 'Register'
                        ? const CatalogPanel()
                        : OrderHistoryPanel(
                            odooClient: odooClient,
                            printerService: printerService,
                            controller: controller,
                            onBackToRegister: () => controller.setActiveTab('Register'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
