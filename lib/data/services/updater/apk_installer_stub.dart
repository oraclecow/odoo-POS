class ApkInstaller {
  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    throw UnsupportedError('In-app APK installation is not supported on web browsers.');
  }
}
