import 'dart:convert';
import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart' as platform;

class UniversalFileSaver {
  UniversalFileSaver._();

  static Future<void> saveOrShareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? shareText,
  }) async {
    await platform.downloadOrShareBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      shareText: shareText,
    );
  }

  static Future<void> saveOrShareString({
    required String content,
    required String fileName,
    String mimeType = 'text/csv;charset=utf-8',
    String? shareText,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    await saveOrShareBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      shareText: shareText,
    );
  }
}
