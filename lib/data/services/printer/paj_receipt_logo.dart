import 'dart:convert';

/// Pick A Juice monochrome thermal raster logo (288x384 dots) for ESC/POS receipts
class PajReceiptLogo {
  static const int widthDots = 288;
  static const int heightDots = 384;
  static const int widthBytes = 36; // 288 / 8

  static List<int>? _cachedRasterEscPos;

  /// Returns the ESC/POS GS v 0 raster bit image commands for thermal printers
  static List<int> getRasterEscPosBytes() {
    if (_b64Data.isEmpty) return const [];
    if (_cachedRasterEscPos != null) return _cachedRasterEscPos!;

    final data = base64.decode(_b64Data);
    final bytes = <int>[
      0x1D, 0x76, 0x30, 0x00, // GS v 0 0 (normal density)
      widthBytes % 256, (widthBytes ~/ 256), // xL, xH
      heightDots % 256, (heightDots ~/ 256), // yL, yH
      ...data,
      0x0A, // Line feed after graphic
    ];

    _cachedRasterEscPos = bytes;
    return bytes;
  }

  static const String _b64Data =
      '';
}
