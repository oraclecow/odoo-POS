import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'updater/apk_installer.dart';
import 'updater/desktop_updater.dart';
import 'updater/web_reloader.dart';

class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String webVersion;
  final String apkUrl;
  final String windowsZipUrl;
  final String linuxTarUrl;
  final String releaseDate;
  final List<String> releaseNotes;

  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.webVersion,
    required this.apkUrl,
    this.windowsZipUrl = '/AraPOS_windows_x64.zip',
    this.linuxTarUrl = '/AraPOS_Modular_Linux_x64.tar.gz',
    required this.releaseDate,
    required this.releaseNotes,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionCode: json['version_code'] as int? ?? 1,
      versionName: json['version_name'] as String? ?? '1.0.0',
      webVersion: json['web_version'] as String? ?? '1.0.0',
      apkUrl: json['apk_url'] as String? ?? '/app-release.apk',
      windowsZipUrl: json['windows_zip_url'] as String? ?? '/AraPOS_windows_x64.zip',
      linuxTarUrl: json['linux_tar_url'] as String? ?? '/AraPOS_Modular_Linux_x64.tar.gz',
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
  final String? activeBaseUrl;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.versionInfo,
    required this.currentVersionCode,
    required this.currentVersionName,
    this.errorMessage,
    this.activeBaseUrl,
  });
}

class AppUpdateService {
  static const int currentVersionCode = 4;
  static const String currentVersionName = '1.0.3';

  /// Check version.json from the active server with multi-tier fallback
  static Future<UpdateCheckResult> checkForUpdates({String? serverBaseUrl}) async {
    List<Uri> candidateUris = [];
    if (kIsWeb) {
      candidateUris.add(Uri.base.resolve('/version.json'));
    } else {
      if (serverBaseUrl != null && serverBaseUrl.isNotEmpty) {
        String base = serverBaseUrl;
        if (base.contains(':8069')) {
          final host = Uri.parse(base).host;
          base = 'http://$host:8089';
        }
        candidateUris.add(Uri.parse('$base/version.json'));
      }
      candidateUris.add(Uri.parse('http://192.168.200.196:8089/version.json'));
      candidateUris.add(Uri.parse('http://192.168.201.201:8089/version.json'));
      candidateUris.add(Uri.parse('https://raw.githubusercontent.com/oraclecow/odoo-POS/main/web/version.json'));
    }

    String? lastError;
    for (final targetUri in candidateUris) {
      try {
        debugPrint('[AppUpdater] Checking version manifest from $targetUri...');
        final resp = await http.get(targetUri).timeout(const Duration(seconds: 3));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final remote = AppVersionInfo.fromJson(data);

          bool hasUpdate = false;
          if (kIsWeb) {
            hasUpdate = remote.webVersion != currentVersionName;
          } else {
            hasUpdate = remote.versionCode > currentVersionCode;
          }

          final origin = targetUri.hasScheme && targetUri.host.isNotEmpty
              ? '${targetUri.scheme}://${targetUri.host}${targetUri.hasPort ? ':${targetUri.port}' : ''}'
              : '';

          return UpdateCheckResult(
            hasUpdate: hasUpdate,
            versionInfo: remote,
            currentVersionCode: currentVersionCode,
            currentVersionName: currentVersionName,
            activeBaseUrl: origin,
          );
        } else {
          lastError = 'HTTP ${resp.statusCode} from $targetUri';
        }
      } catch (e) {
        lastError = '$e from $targetUri';
        debugPrint('[AppUpdater] Failed $targetUri: $e');
      }
    }

    return UpdateCheckResult(
      hasUpdate: false,
      currentVersionCode: currentVersionCode,
      currentVersionName: currentVersionName,
      errorMessage: lastError ?? 'Unable to connect to any update servers',
    );
  }

  /// Download APK with progress and trigger system installer (Android)
  static Future<void> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    await ApkInstaller.downloadAndInstall(
      downloadUrl: downloadUrl,
      onProgress: onProgress,
    );
  }

  /// Download and apply desktop release bundle and restart application (Windows/Linux)
  static Future<void> downloadAndApplyDesktopUpdate({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    await DesktopUpdater.downloadAndApplyUpdate(
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
