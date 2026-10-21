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
  mm80('80 mm (48 Columns) - Standard POS'),
  mm58('58 mm (32 Columns) - Compact / Mobile');

  final String label;
  const PrinterPaperWidth(this.label);
}

enum PrinterPreset {
  usbDirect58(
    id: 'usb_direct_58',
    name: 'USB Thermal 58mm (Direct)',
    badge: 'USB 58mm',
    subtitle: 'Local USB POS Printer (32 Columns)',
    type: PrinterConnectionType.usb,
    width: PrinterPaperWidth.mm58,
    cutter: false,
  ),
  usbDirect80(
    id: 'usb_direct_80',
    name: 'USB Thermal 80mm (Direct)',
    badge: 'USB 80mm',
    subtitle: 'Local USB POS Printer (48 Columns, Auto-Cut)',
    type: PrinterConnectionType.usb,
    width: PrinterPaperWidth.mm80,
    cutter: true,
  ),
  lanRaw9100(
    id: 'lan_raw_9100',
    name: 'Network LAN (RAW TCP:9100)',
    badge: 'LAN RAW',
    subtitle: 'Direct TCP socket to Ethernet/Wi-Fi printer',
    type: PrinterConnectionType.lan,
    ip: '192.168.1.100',
    port: 9100,
    width: PrinterPaperWidth.mm80,
    cutter: true,
  ),
  eposHttp(
    id: 'epos_http',
    name: 'Epson ePOS / XML HTTP',
    badge: 'ePOS XML',
    subtitle: 'Direct HTTP XML printing to Epson network printer',
    type: PrinterConnectionType.epos,
    ip: '192.168.1.100',
    port: 80,
    eposUrl: 'http://192.168.1.100/cgi-bin/epos/service.cgi?devid=local_printer',
    width: PrinterPaperWidth.mm80,
    cutter: true,
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
    this.ip = '192.168.1.100',
    this.port = 9100,
    this.eposUrl = 'http://192.168.1.100/cgi-bin/epos/service.cgi?devid=local_printer',
    this.width = PrinterPaperWidth.mm80,
    this.cutter = false,
  });

  static PrinterPreset fromId(String? id) {
    return PrinterPreset.values.firstWhere(
      (p) => p.id == id,
      orElse: () => PrinterPreset.usbDirect58,
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
    this.windowsPrinterName = 'POS-58',
    this.ipAddress = '192.168.1.100',
    this.port = 9100,
    this.eposEndpoint = 'http://192.168.1.100/cgi-bin/epos/service.cgi?devid=local_printer',
    this.bluetoothName = 'BT-Printer',
    this.paperWidth = PrinterPaperWidth.mm58,
    this.autoCutter = false,
    this.autoPrintReceipt = true,
    this.autoPrintKitchen = false,
    this.activePresetId = 'usb_direct_58',
  });

  String get activeBadgeName {
    if (connectionType == PrinterConnectionType.disabled) return 'Disabled';
    if (connectionType == PrinterConnectionType.usb) return 'USB Local';
    if (connectionType == PrinterConnectionType.lan) return 'LAN (RAW:9100)';
    if (connectionType == PrinterConnectionType.epos) return 'ePOS (HTTP)';
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

      settings.windowsPrinterName = prefs.getString('printer_windows_name') ?? 'POS-58';
      settings.ipAddress = prefs.getString('printer_ip') ?? '192.168.1.100';
      settings.port = prefs.getInt('printer_port') ?? 9100;
      settings.eposEndpoint = prefs.getString('printer_epos_endpoint') ??
          'http://${settings.ipAddress}/cgi-bin/epos/service.cgi?devid=local_printer';
      settings.bluetoothName = prefs.getString('printer_bluetooth_name') ?? 'BT-Printer';

      final widthStr = prefs.getString('printer_paper_width');
      if (widthStr != null) {
        settings.paperWidth = PrinterPaperWidth.values.firstWhere(
          (e) => e.name == widthStr,
          orElse: () => PrinterPaperWidth.mm58,
        );
      }

      settings.autoCutter = prefs.getBool('printer_auto_cutter') ?? false;
      settings.autoPrintReceipt = prefs.getBool('printer_auto_receipt') ?? true;
      settings.autoPrintKitchen = prefs.getBool('printer_auto_kitchen') ?? false;
      settings.activePresetId = prefs.getString('printer_active_preset') ?? 'usb_direct_58';
    } catch (_) {}
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
      await prefs.setBool('printer_auto_receipt', autoPrintReceipt);
      await prefs.setBool('printer_auto_kitchen', autoPrintKitchen);
      await prefs.setString('printer_active_preset', activePresetId);
    } catch (_) {}
  }
}
