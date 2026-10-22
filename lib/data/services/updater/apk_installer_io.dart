import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApkInstaller {
  static const MethodChannel _channel = MethodChannel('com.arawali.pos/updater');

  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    final client = http.Client();
    try {
      debugPrint('[ApkInstaller] Downloading APK from $downloadUrl...');
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      // Temporary file in system cache
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/app-update.apk');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      final sink = file.openWrite();
      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
          onProgress(progress, receivedBytes, totalBytes);
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();

      debugPrint('[ApkInstaller] Download complete (${file.path}, $receivedBytes bytes). Launching package installer...');

      final success = await _channel.invokeMethod<bool>('installApk', {
        'filePath': file.path,
      });

      if (success != true) {
        throw Exception('Failed to launch Android package installer.');
      }
    } finally {
      client.close();
    }
  }
}
