import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'updater/apk_installer.dart';
import 'updater/web_reloader.dart';

class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String webVersion;
  final String apkUrl;
  final String releaseDate;
  final List<String> releaseNotes;

  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.webVersion,
    required this.apkUrl,
    required this.releaseDate,
    required this.releaseNotes,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionCode: json['version_code'] as int? ?? 1,
      versionName: json['version_name'] as String? ?? '1.0.0',
      webVersion: json['web_version'] as String? ?? '1.0.0',
      apkUrl: json['apk_url'] as String? ?? '/app-release.apk',
      releaseDate: json['release_date'] as String? ?? '',
      releaseNotes: (json['release_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class UpdateCheckResult {
  final bool hasUpdate;
  final AppVersionInfo? versionInfo;
  final int currentVersionCode;
  final String currentVersionName;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.versionInfo,
    required this.currentVersionCode,
    required this.currentVersionName,
    this.errorMessage,
  });
}

class AppUpdateService {
  static const int currentVersionCode = 3;
  static const String currentVersionName = '1.0.2';

  /// Check version.json from the active server
  static Future<UpdateCheckResult> checkForUpdates({String? serverBaseUrl}) async {
    try {
      Uri targetUri;
      if (kIsWeb) {
        targetUri = Uri.base.resolve('/version.json');
      } else {
        String base = serverBaseUrl ?? 'http://192.168.200.196:8089';
        if (base.contains(':8069')) {
          final host = Uri.parse(base).host;
          base = 'http://$host:8089';
        }
        targetUri = Uri.parse('$base/version.json');
      }

      debugPrint('[AppUpdater] Fetching version manifest from $targetUri...');
      final resp = await http.get(targetUri).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final remote = AppVersionInfo.fromJson(data);

        bool hasUpdate = false;
        if (kIsWeb) {
          hasUpdate = remote.webVersion != currentVersionName;
        } else {
          hasUpdate = remote.versionCode > currentVersionCode;
        }

        return UpdateCheckResult(
          hasUpdate: hasUpdate,
          versionInfo: remote,
          currentVersionCode: currentVersionCode,
          currentVersionName: currentVersionName,
        );
      } else {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersionCode: currentVersionCode,
          currentVersionName: currentVersionName,
          errorMessage: 'Server HTTP ${resp.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[AppUpdater] Check error: $e');
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersionCode: currentVersionCode,
        currentVersionName: currentVersionName,
        errorMessage: e.toString(),
      );
    }
  }

  /// Download APK with progress and trigger system installer
  static Future<void> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    await ApkInstaller.downloadAndInstall(
      downloadUrl: downloadUrl,
      onProgress: onProgress,
    );
  }

  /// Trigger browser refresh for Web POS
  static void reloadWebApp() {
    reloadWindow();
  }

  /// Trigger browser download of APK file
  static void downloadApkWeb({String filename = 'PAJ-POS.apk', String path = '/app-release.apk'}) {
    triggerWebDownload(path, filename);
  }
}
