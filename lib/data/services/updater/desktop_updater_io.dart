import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DesktopUpdater {
  static Future<void> downloadAndApplyUpdate({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux) {
      throw UnsupportedError('Platform not supported for desktop updater: ${Platform.operatingSystem}');
    }

    final client = http.Client();
    try {
      debugPrint('[DesktopUpdater] Starting download from: $downloadUrl');
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException('Download failed with HTTP ${response.statusCode} from $downloadUrl');
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = Directory.systemTemp.createTempSync('arapos_update_');
      final isWin = Platform.isWindows;
      final archiveFile = File('${tempDir.path}/${isWin ? "update.zip" : "update.tar.gz"}');
      final sink = archiveFile.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress(received / contentLength, received, contentLength);
        } else {
          onProgress(0.5, received, received);
        }
      }
      await sink.flush();
      await sink.close();

      onProgress(1.0, received, received);
      debugPrint('[DesktopUpdater] Download complete (${archiveFile.lengthSync()} bytes)');

      final appExe = Platform.resolvedExecutable;
      final appDir = File(appExe).parent.path;
      debugPrint('[DesktopUpdater] App directory: $appDir');

      if (isWin) {
        final batFile = File('${tempDir.path}/apply_update.bat');
        final script = '''@echo off
timeout /t 2 /nobreak >nul
set "APP_DIR=%~1"
set "ZIP_PATH=%~2"
set "EXTRACT_DIR=%TEMP%\\arapos_extract_%RANDOM%"

echo [AraPOS Updater] Extracting update package...
powershell -NoProfile -ExecutionPolicy Bypass -Command "\$app = '%APP_DIR%'; \$zip = '%ZIP_PATH%'; \$ext = '%EXTRACT_DIR%'; Expand-Archive -Path \$zip -DestinationPath \$ext -Force; foreach (\$cfg in @('pos_config.json', 'receipt_config.json')) { if (Test-Path (Join-Path \$app \$cfg)) { Copy-Item (Join-Path \$app \$cfg) \$ext -Force } }; Copy-Item (Join-Path \$ext '*') \$app -Recurse -Force; Remove-Item \$ext -Recurse -Force; Remove-Item \$zip -Force"

cd /d "%APP_DIR%"
echo [AraPOS Updater] Restarting POS...
if exist "AraPOS.exe" (
  start "" "AraPOS.exe"
) else if exist "ArawaliPOS.exe" (
  start "" "ArawaliPOS.exe"
) else (
  start "" "arapos.exe"
)
exit /b 0
''';
        batFile.writeAsStringSync(script);
        debugPrint('[DesktopUpdater] Launching detached Windows helper script: ${batFile.path}');
        await Process.start(
          'cmd.exe',
          ['/c', 'start', '', batFile.path, appDir, archiveFile.path],
          mode: ProcessStartMode.detached,
        );
      } else {
        final shFile = File('${tempDir.path}/apply_update.sh');
        final script = '''#!/usr/bin/env bash
APP_DIR="\$1"
TAR_PATH="\$2"
sleep 2

EXTRACT_DIR="/tmp/arapos_extract_\$\$"
mkdir -p "\$EXTRACT_DIR"
tar -xzf "\$TAR_PATH" -C "\$EXTRACT_DIR"

SRC_DIR="\$EXTRACT_DIR"
if [ -d "\$EXTRACT_DIR/AraPOS_Modular_Linux" ]; then
  SRC_DIR="\$EXTRACT_DIR/AraPOS_Modular_Linux"
fi

# Copy assets and binaries over app directory
cp -a "\$SRC_DIR/lib"/* "\$APP_DIR/lib/" 2>/dev/null || true
cp -a "\$SRC_DIR/data"/* "\$APP_DIR/data/" 2>/dev/null || true
cp -a "\$SRC_DIR/arapos" "\$APP_DIR/arapos" 2>/dev/null || true
cp -a "\$SRC_DIR/flutter_odoo_pos" "\$APP_DIR/flutter_odoo_pos" 2>/dev/null || true

# Cleanup
rm -rf "\$EXTRACT_DIR" "\$TAR_PATH"

# Relaunch POS
cd "\$APP_DIR"
if [ -x "./START_POS_LINUX.sh" ]; then
  nohup ./START_POS_LINUX.sh >/dev/null 2>&1 &
elif [ -x "./arapos" ]; then
  nohup ./arapos >/dev/null 2>&1 &
else
  nohup ./flutter_odoo_pos >/dev/null 2>&1 &
fi
exit 0
''';
        shFile.writeAsStringSync(script);
        Process.runSync('chmod', ['+x', shFile.path]);
        debugPrint('[DesktopUpdater] Launching detached Linux helper script: ${shFile.path}');
        await Process.start(
          '/bin/bash',
          [shFile.path, appDir, archiveFile.path],
          mode: ProcessStartMode.detached,
        );
      }

      await Future.delayed(const Duration(milliseconds: 600));
      exit(0);
    } finally {
      client.close();
    }
  }
}
