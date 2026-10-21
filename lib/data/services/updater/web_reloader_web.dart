// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void reloadWindow() {
  try {
    html.window.location.reload();
  } catch (_) {}
}

void triggerWebDownload(String url, String filename) {
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  } catch (_) {
    html.window.open(url, '_blank');
  }
}
