import 'dart:html' as html;

class ImageSaver {
  static Future<String> saveBytes(List<int> bytes) async {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = 'graph_export_${DateTime.now().millisecondsSinceEpoch}.png'
      ..click();
    html.Url.revokeObjectUrl(url);
    return 'download';
  }
}


