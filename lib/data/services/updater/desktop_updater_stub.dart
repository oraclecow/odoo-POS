class DesktopUpdater {
  static Future<void> downloadAndApplyUpdate({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    throw UnsupportedError('DesktopUpdater is only supported on Desktop (Windows/Linux)');
  }
}
