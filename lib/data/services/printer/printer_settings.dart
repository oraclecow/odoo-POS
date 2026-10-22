import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterConnectionType {
  usb('USB Thermal Printer (Direct / Spooler)'),
  lan('LAN / Ethernet (TCP RAW:9100)'),
  epos('Epson ePOS (HTTP XML)'),
  bluetooth('Bluetooth ESC/POS'),
  disabled('Disable Printing (Silent Mode)');

  final String label;
  const PrinterConnectionType(this.label);
}

enum PrinterPaperWidth {
  mm80('80 mm (48 Columns) - Restaurant / Cashier Standard'),
  mm58('58 mm (32 Columns) - Mini Portable');

  final String label;
  const PrinterPaperWidth(this.label);
}

enum PrinterPreset {
  cobUsb58(
    id: 'cob_usb_58',
    name: 'USB Local (Direct Windows)',
    badge: 'USB Local',
    subtitle: 'Physical USB on this PC (58mm Series Printer)',
    type: PrinterConnectionType.usb,
    width: PrinterPaperWidth.mm58,
    cutter: false,
  ),
  officeCob1(
    id: 'office_cob_1',
    name: 'COB (Remote Network)',
    badge: 'COB Remote',
    subtitle: 'Print over LAN to COB (192.168.201.193 ePOS)',
    type: PrinterConnectionType.epos,
    ip: '192.168.201.193',
    port: 80,
    eposUrl: 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer',
    width: PrinterPaperWidth.mm58,
    cutter: false,
  ),
  disabled(
    id: 'disabled',
    name: 'Disable Printing',
    badge: 'Disabled',
    subtitle: 'No physical printout (Silent test mode)',
    type: PrinterConnectionType.disabled,
    cutter: false,
  );

  final String id;
  final String name;
  final String badge;
  final String subtitle;
  final PrinterConnectionType type;
  final String ip;
  final int port;
  final String eposUrl;
  final PrinterPaperWidth width;
  final bool cutter;

  const PrinterPreset({
    required this.id,
    required this.name,
    required this.badge,
    required this.subtitle,
    required this.type,
    this.ip = '192.168.201.193',
    this.port = 80,
    this.eposUrl = 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer',
    this.width = PrinterPaperWidth.mm58,
    this.cutter = false,
  });

  static PrinterPreset fromId(String? id) {
    return PrinterPreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => PrinterPreset.cobUsb58,
    );
  }
}

class PrinterSettings {
  PrinterConnectionType connectionType;
  String windowsPrinterName;
  String ipAddress;
  int port;
  String eposEndpoint;
  String bluetoothName;
  PrinterPaperWidth paperWidth;
  bool autoCutter;
  bool autoPrintReceipt;
  bool autoPrintKitchen;
  String activePresetId;

  PrinterSettings({
    this.connectionType = PrinterConnectionType.usb,
    this.windowsPrinterName = '58mm Series Printer',
    this.ipAddress = '192.168.201.193',
    this.port = 80,
    this.eposEndpoint = 'http://192.168.201.193/cgi-bin/epos/service.cgi?devid=local_printer',
    this.bluetoothName = 'Blueprint BP-Lite 80L',
    this.paperWidth = PrinterPaperWidth.mm58,
    this.autoCutter = false,
    this.autoPrintReceipt = true,
    this.autoPrintKitchen = false,
    this.activePresetId = 'cob_usb_58',
  });

  String get activeBadgeName {
    if (connectionType == PrinterConnectionType.disabled) return 'Disabled';
    if (connectionType == PrinterConnectionType.usb) return 'USB Local';
    if (connectionType == PrinterConnectionType.epos) return 'COB (Remote)';
    return 'Active';
  }

  void applyPreset(PrinterPreset preset) {
    activePresetId = preset.id;
    connectionType = preset.type;
    paperWidth = preset.width;
    autoCutter = preset.cutter;
    if (preset.type == PrinterConnectionType.lan) {
      ipAddress = preset.ip;
      port = preset.port;
    } else if (preset.type == PrinterConnectionType.epos) {
      ipAddress = preset.ip;
      port = preset.port;
      eposEndpoint = preset.eposUrl;
    }
  }

  static Future<PrinterSettings> load() async {
    final settings = PrinterSettings();
    try {
      final prefs = await SharedPreferences.getInstance();
      final typeStr = prefs.getString('printer_connection_type');
      if (typeStr != null) {
        settings.connectionType = PrinterConnectionType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => PrinterConnectionType.usb,
        );
      }

      settings.windowsPrinterName = prefs.getString('printer_windows_name') ?? '58mm Series Printer';
      settings.ipAddress = prefs.getString('printer_ip') ?? '192.168.201.193';
      settings.port = prefs.getInt('printer_port') ?? 80;
      settings.eposEndpoint = prefs.getString('printer_epos_endpoint') ??
          'http://${settings.ipAddress}/cgi-bin/epos/service.cgi?devid=local_printer';
      settings.bluetoothName = prefs.getString('printer_bluetooth_name') ?? 'Blueprint BP-Lite 80L';

      final widthStr = prefs.getString('printer_paper_width');
      if (widthStr != null) {
        settings.paperWidth = PrinterPaperWidth.values.firstWhere(
          (e) => e.name == widthStr,
          orElse: () => PrinterPaperWidth.mm58,
        );
      }

      settings.autoCutter = prefs.getBool('printer_auto_cutter') ?? false;
      settings.autoPrintReceipt = prefs.getBool('printer_auto_print_receipt') ?? true;
      settings.autoPrintKitchen = prefs.getBool('printer_auto_print_kitchen') ?? false;
      settings.activePresetId = prefs.getString('printer_active_preset_id') ?? 'cob_usb_58';
      debugPrint('[PrinterSettings] Loaded: preset=${settings.activePresetId}, type=${settings.connectionType.name}, winPrinter="${settings.windowsPrinterName}", epos="${settings.eposEndpoint}"');
    } catch (e) {
      debugPrint('[PrinterSettings] Error loading prefs: $e');
    }
    return settings;
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_connection_type', connectionType.name);
      await prefs.setString('printer_windows_name', windowsPrinterName);
      await prefs.setString('printer_ip', ipAddress);
      await prefs.setInt('printer_port', port);
      await prefs.setString('printer_epos_endpoint', eposEndpoint);
      await prefs.setString('printer_bluetooth_name', bluetoothName);
      await prefs.setString('printer_paper_width', paperWidth.name);
      await prefs.setBool('printer_auto_cutter', autoCutter);
      await prefs.setBool('printer_auto_print_receipt', autoPrintReceipt);
      await prefs.setBool('printer_auto_print_kitchen', autoPrintKitchen);
      await prefs.setString('printer_active_preset_id', activePresetId);
      debugPrint('[PrinterSettings] Saved: preset=$activePresetId, type=${connectionType.name}, winPrinter="$windowsPrinterName", epos="$eposEndpoint"');
    } catch (e) {
      debugPrint('[PrinterSettings] Error saving prefs: $e');
    }
  }
}
