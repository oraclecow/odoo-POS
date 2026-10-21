import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'windows_spooler_printer.dart';

class PrinterTransport {
  static Future<Map<String, dynamic>> sendRawBytes({
    required String host,
    required int port,
    required List<int> bytes,
  }) async {
    Socket? socket;
    try {
      debugPrint('[Printer IO] Connecting to TCP $host:$port...');
      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      debugPrint('[Printer IO] Successfully sent ${bytes.length} bytes to $host:$port');
      return {
        'success': true,
        'simulated': false,
        'message': 'Berhasil terkirim ke printer $host:$port (${bytes.length} bytes)',
      };
    } catch (e) {
      debugPrint('[Printer IO Error] Failed to connect $host:$port: $e');
      return {
        'success': false,
        'simulated': false,
        'message': 'Gagal mencetak ke $host:$port: $e',
      };
    } finally {
      socket?.destroy();
    }
  }

  static Future<Map<String, dynamic>> sendEposXml({
    required String endpoint,
    required String xml,
  }) async {
    HttpClient? client;
    try {
      debugPrint('[Printer IO ePOS] Sending ePOS XML to $endpoint...');
      final uri = Uri.parse(endpoint);
      client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
      request.write(xml);
      final response = await request.close();
      final body = await response.transform(const Utf8Decoder(allowMalformed: true)).join();

      final success = response.statusCode == 200 && body.contains('success="true"');
      return {
        'success': success,
        'simulated': false,
        'message': success ? 'Berhasil dicetak ke ePOS (${response.statusCode})' : 'Gagal ePOS: HTTP ${response.statusCode}',
      };
    } catch (e) {
      debugPrint('[Printer IO ePOS Error] $e');
      return {
        'success': false,
        'simulated': false,
        'message': 'Gagal koneksi ePOS $endpoint: $e',
      };
    } finally {
      client?.close();
    }
  }

  static Future<Map<String, dynamic>> sendUsbBytes(
    List<int> bytes, {
    String? printerName,
    String label = 'Receipt',
  }) async {
    try {
      if (Platform.isWindows) {
        return await WindowsSpoolerPrinter.printRawBytes(
          bytes,
          printerName: printerName,
          docName: 'POS $label',
        );
      } else if (Platform.isLinux) {
        for (final path in ['/dev/usb/lp0', '/dev/usb/lp1']) {
          final file = File(path);
          if (file.existsSync()) {
            await file.writeAsBytes(bytes);
            return {
              'success': true,
              'simulated': false,
              'message': 'Berhasil dicetak ke USB printer ($path)',
            };
          }
        }
      }
      return {
        'success': true,
        'simulated': true,
        'message': 'Driver USB siap ($label: ${bytes.length} bytes diproses). Pastikan printer USB terpasang.',
      };
    } catch (e) {
      return {
        'success': false,
        'simulated': false,
        'message': 'Gagal mencetak ke printer USB: $e',
      };
    }
  }

  static String? getDefaultPrinterName() {
    if (Platform.isWindows) {
      return WindowsSpoolerPrinter.getDefaultPrinter();
    }
    return null;
  }
}
