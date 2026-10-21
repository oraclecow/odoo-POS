import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PrinterTransport {
  static Future<Map<String, dynamic>> sendRawBytes({
    required String host,
    required int port,
    required List<int> bytes,
  }) async {
    final endpoint = Uri.base.resolve('/api/print_raw');
    debugPrint('[Printer Web Bridge] Dispatching ${bytes.length} bytes to $host:$port via $endpoint');

    try {
      final resp = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'host': host,
          'port': port,
          'bytes': base64Encode(bytes),
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return {
          'success': data['success'] == true,
          'simulated': false,
          'message': data['message'] ?? 'Berhasil dicetak.',
        };
      } else {
        String errMsg = 'HTTP ${resp.statusCode}';
        try {
          final data = jsonDecode(resp.body);
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
          }
        } catch (_) {}
        return {
          'success': false,
          'simulated': false,
          'message': 'Gagal cetak melalui web bridge: $errMsg',
        };
      }
    } catch (e) {
      debugPrint('[Printer Web Error] $e');
      return {
        'success': false,
        'simulated': false,
        'message': 'Gagal menghubungi server web bridge ($endpoint): $e',
      };
    }
  }

  static Future<Map<String, dynamic>> sendEposXml({
    required String endpoint,
    required String xml,
  }) async {
    final proxyEndpoint = Uri.base.resolve('/api/print_epos');
    debugPrint('[Printer Web ePOS Bridge] Dispatching ePOS XML to $endpoint via $proxyEndpoint');

    try {
      final resp = await http.post(
        proxyEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'endpoint': endpoint,
          'xml': xml,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return {
          'success': data['success'] == true,
          'simulated': false,
          'message': data['message'] ?? 'Berhasil dicetak ke ePOS.',
        };
      } else {
        String errMsg = 'HTTP ${resp.statusCode}';
        try {
          final data = jsonDecode(resp.body);
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
          }
        } catch (_) {}
        return {
          'success': false,
          'simulated': false,
          'message': 'Gagal cetak ePOS via bridge: $errMsg',
        };
      }
    } catch (e) {
      debugPrint('[Printer Web ePOS Error] $e');
      return {
        'success': false,
        'simulated': false,
        'message': 'Gagal menghubungi server ePOS bridge ($proxyEndpoint): $e',
      };
    }
  }

  static Future<Map<String, dynamic>> sendUsbBytes(List<int> bytes, {String? printerName, String label = 'Receipt'}) async {
    return await sendRawBytes(
      host: '127.0.0.1',
      port: 9100,
      bytes: bytes,
    );
  }

  static String? getDefaultPrinterName() => null;
}
