// lib/core/logo_codec.dart
// Letterhead logos are stored inline on the template as a `data:` URI so no
// storage bucket is needed and PDF/preview can render them synchronously.

import 'dart:convert';
import 'dart:typed_data';

/// Decodes a `data:image/...;base64,` URI into bytes. Returns null for
/// anything else (null, empty, http URLs, malformed data).
Uint8List? logoBytesFromDataUri(String? uri) {
  if (uri == null || !uri.startsWith('data:')) return null;
  final i = uri.indexOf('base64,');
  if (i < 0) return null;
  try {
    return base64Decode(uri.substring(i + 7));
  } catch (_) {
    return null;
  }
}

/// Encodes image bytes as a `data:` URI suitable for SchoolExamTemplate.schoolLogoUrl.
String logoDataUriFromBytes(Uint8List bytes, {String mime = 'image/png'}) =>
    'data:$mime;base64,${base64Encode(bytes)}';
