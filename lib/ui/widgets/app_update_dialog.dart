import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/services/app_update_service.dart';
import '../core/app_colors.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppVersionInfo versionInfo;
  final String serverBaseUrl;

  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.serverBaseUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required AppVersionInfo versionInfo,
    required String serverBaseUrl,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(
        versionInfo: versionInfo,
        serverBaseUrl: serverBaseUrl,
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  String _formatMb(int bytes) {
    return (bytes / (1024 * 1024)).toStringAsFixed(1);
  }

  Future<void> _startAndroidUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      // Resolve APK absolute URL
      String apkUrl = widget.versionInfo.apkUrl;
      if (!apkUrl.startsWith('http')) {
        String base = widget.serverBaseUrl;
        if (base.contains(':8069')) {
          final host = Uri.parse(base).host;
          base = 'http://$host:8089';
        }
        apkUrl = '$base$apkUrl';
      }

      await AppUpdateService.downloadAndInstallApk(
        downloadUrl: apkUrl,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.versionInfo;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.system_update_rounded, color: Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Application Update Available',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version ${info.versionName} (Build ${info.versionCode}) • ${info.releaseDate}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (!_isDownloading)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 10),

              // Version Badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Current: v${AppUpdateService.currentVersionName}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      'Latest: v${info.versionName}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Release Notes
              const Text(
                'Release Notes / What\'s New:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: info.releaseNotes.isEmpty
                      ? [const Text('General performance improvements and stability bug fixes.', style: TextStyle(fontSize: 12))]
                      : info.releaseNotes
                          .map((note) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                                    Expanded(child: Text(note, style: const TextStyle(fontSize: 12.5))),
                                  ],
                                ),
                              ))
                          .toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Failed: $_errorMessage',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                  ),
                ),
              ],

              // Downloading Progress
              if (_isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloading APK (${(_progress * 100).toInt()}%)...',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        if (_totalBytes > 0)
                          Text(
                            '${_formatMb(_receivedBytes)} MB / ${_formatMb(_totalBytes)} MB',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Once completed, the Android Package Installer will open automatically.',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Action Buttons
              if (!_isDownloading)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Later'),
                    ),
                    const SizedBox(width: 8),
                    if (kIsWeb) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.install_mobile_rounded, size: 18),
                        label: const Text('Download APK (51 MB)'),
                        onPressed: () {
                          AppUpdateService.downloadApkWeb();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Downloading PAJ POS Android APK installer...'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Web Button: Refresh Web POS
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reload Web POS', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          AppUpdateService.reloadWebApp();
                        },
                      ),
                    ] else ...[
                      // Android Native Button: Download & Install
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download & Install Now', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _startAndroidUpdate,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
