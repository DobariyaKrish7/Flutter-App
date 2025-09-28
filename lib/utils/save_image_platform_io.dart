import 'dart:io';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageSaver {
  static Future<String> saveBytes(List<int> bytes) async {
    // Request permissions per platform
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      if (!status.isGranted) {
        throw Exception('Photos permission denied');
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/graph_export_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    try {
      await GallerySaver.saveImage(file.path);
    } catch (_) {}
    return file.path;
  }
}


