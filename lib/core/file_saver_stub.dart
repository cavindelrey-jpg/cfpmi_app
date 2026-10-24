import 'dart:typed_data';

Future<void> downloadOrShareBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? shareText,
}) async {
  throw UnsupportedError('Cannot save file on this platform');
}
