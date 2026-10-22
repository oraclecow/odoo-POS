import 'dart:convert';

class EscPosDocument {
  final List<int> bytes;
  final String previewText;

  const EscPosDocument({
    required this.bytes,
    required this.previewText,
  });
}

/// Pure ESC/POS byte & preview-text builder.
/// Eliminates duplicate byte/textBuffer calls in receipt templates.
class EscPosBuilder {
  final int cols;
  final List<int> _bytes = <int>[];
  final StringBuffer _text = StringBuffer();

  // Standard ESC/POS Command Constants
  static const List<int> cmdInit = [0x1B, 0x40]; // ESC @
  static const List<int> cmdAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> cmdAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> cmdBoldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> cmdBoldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> cmdDoubleSize = [0x1D, 0x21, 0x11]; // GS ! 0x11
  static const List<int> cmdNormalSize = [0x1D, 0x21, 0x00]; // GS ! 0x00
  static const List<int> cmdFeedLines = [0x0A, 0x0A, 0x0A, 0x0A, 0x0A]; // 5 Line Feeds
  static const List<int> cmdCut = [0x1D, 0x56, 0x42, 0x00]; // GS V 'B' 0 (Full Cut)
  static const List<int> cmdDrawerKick = [0x1B, 0x70, 0x00, 0x19, 0xFA]; // ESC p 0 25 250

  EscPosBuilder({required this.cols}) {
    _bytes.addAll(cmdInit);
  }

  void rawBytes(List<int> data, {bool center = false}) {
    if (data.isEmpty) return;
    if (center) _bytes.addAll(cmdAlignCenter);
    _bytes.addAll(data);
  }

  void title(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _bytes.addAll(cmdAlignCenter);
    _bytes.addAll(cmdDoubleSize);
    _bytes.addAll(cmdBoldOn);
    _bytes.addAll(encodeEscPos("$clean\n"));
    _bytes.addAll(cmdNormalSize);
    _bytes.addAll(cmdBoldOff);
    _text.writeln(centerText(clean, cols));
  }

  void centerLine(String text, {bool bold = false, bool doubleSize = false}) {
    _bytes.addAll(cmdAlignCenter);
    if (doubleSize) _bytes.addAll(cmdDoubleSize);
    if (bold) _bytes.addAll(cmdBoldOn);
    _bytes.addAll(encodeEscPos("$text\n"));
    if (doubleSize) _bytes.addAll(cmdNormalSize);
    if (bold) _bytes.addAll(cmdBoldOff);
    _text.writeln(centerText(text, cols));
  }

  void centerMultiline(String text, {bool bold = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _bytes.addAll(cmdAlignCenter);
    if (bold) _bytes.addAll(cmdBoldOn);
    for (final line in trimmed.split('\n')) {
      _bytes.addAll(encodeEscPos("$line\n"));
      _text.writeln(centerText(line, cols));
    }
    if (bold) _bytes.addAll(cmdBoldOff);
  }

  void leftLine(String text, {bool bold = false, bool doubleSize = false}) {
    _bytes.addAll(cmdAlignLeft);
    if (doubleSize) _bytes.addAll(cmdDoubleSize);
    if (bold) _bytes.addAll(cmdBoldOn);
    _bytes.addAll(encodeEscPos("$text\n"));
    if (doubleSize) _bytes.addAll(cmdNormalSize);
    if (bold) _bytes.addAll(cmdBoldOff);
    _text.writeln(text);
  }

  void row(String left, String right, {bool bold = false}) {
    _bytes.addAll(cmdAlignLeft);
    if (bold) _bytes.addAll(cmdBoldOn);
    final formatted = formatRow(left, right, cols);
    _bytes.addAll(encodeEscPos(formatted));
    if (bold) _bytes.addAll(cmdBoldOff);
    _text.write(formatted);
  }

  void divider([String char = '-']) {
    final line = char * cols;
    _bytes.addAll(encodeEscPos("$line\n"));
    _text.writeln(line);
  }

  void doubleDivider() => divider('=');

  void blankLine() {
    _bytes.addAll(encodeEscPos("\n"));
    _text.writeln();
  }

  EscPosDocument build({required bool autoCutter, required bool is80mm, bool trailingBlankLine = false}) {
    _bytes.addAll(cmdFeedLines);
    if (trailingBlankLine) {
      _text.writeln();
    }
    // Rule 6: Only send cutter if 80mm and cutter enabled. NEVER send cut on 58mm.
    if (autoCutter && is80mm) {
      _bytes.addAll(cmdCut);
    }
    return EscPosDocument(
      bytes: List<int>.unmodifiable(_bytes),
      previewText: _text.toString(),
    );
  }

  static String formatRow(String left, String right, int totalWidth) {
    left = stripHighUnicode(left);
    right = stripHighUnicode(right);
    if (left.length + right.length >= totalWidth) {
      final maxLeft = totalWidth - right.length - 1;
      left = maxLeft > 0 ? left.substring(0, maxLeft) : left;
    }
    final spaces = totalWidth - left.length - right.length;
    return "$left${' ' * (spaces > 0 ? spaces : 1)}$right\n";
  }

  static String centerText(String text, int width) {
    if (text.length >= width) return text;
    final leftPadding = (width - text.length) ~/ 2;
    return '${' ' * leftPadding}$text';
  }

  static List<int> encodeEscPos(String text) {
    return latin1.encode(stripHighUnicode(text));
  }

  static String stripHighUnicode(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      if (char <= 0x7E || (char >= 0xA0 && char <= 0xFF)) {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

  static String buildEposXml({
    String? textContent,
    List<int>? bytes,
    required bool autoCutter,
    required bool is80mm,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    buffer.writeln('<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">');
    buffer.writeln('<s:Body>');
    buffer.writeln('<epos-print xmlns="http://www.epson-pos.com/schemas/2011/03/epos-print">');

    if (bytes != null && bytes.isNotEmpty) {
      final hexData = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      buffer.writeln('<command>$hexData</command>');
    } else if (textContent != null && textContent.trim().isNotEmpty) {
      final escaped = textContent
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      buffer.writeln('<text>$escaped</text>');
      buffer.writeln('<feed line="5"/>');
    }

    if (autoCutter && is80mm) {
      buffer.writeln('<cut type="feed"/>');
    }

    buffer.writeln('</epos-print>');
    buffer.writeln('</s:Body>');
    buffer.writeln('</s:Envelope>');
    return buffer.toString();
  }
}
