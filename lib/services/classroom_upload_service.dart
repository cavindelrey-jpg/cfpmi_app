// lib/services/classroom_upload_service.dart
// Uploads classroom files (slide images, the original .pptx/.pdf, and
// resources) to the shared Supabase Storage bucket 'app-content' under a
// classroom/<schoolId>/ prefix. Uses uploadBinary(bytes) so it works on web
// (the teacher's laptop) as well as mobile — the existing File-based uploader
// is mobile-only.

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';

class ClassroomUploadService {
  ClassroomUploadService._();
  static final ClassroomUploadService instance = ClassroomUploadService._();

  static const String _bucket = 'app-content';

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<Result<String>> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String schoolId,
  }) async {
    final db = _db;
    if (db == null) return const Failure('Upload is offline right now.');
    if (db.auth.currentUser == null) {
      return const Failure('Guests cannot upload files. Please sign in as a teacher or administrator.');
    }
    try {
      final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ext = safe.contains('.') ? safe.split('.').last.toLowerCase() : '';
      final path = 'classroom/${schoolId.isEmpty ? 'shared' : schoolId}/'
          '${DateTime.now().millisecondsSinceEpoch}_$safe';
      await db.storage
          .from(_bucket)
          .uploadBinary(path, bytes,
              fileOptions: FileOptions(contentType: mimeForExt(ext), upsert: true))
          .timeout(const Duration(minutes: 5));
      return Success(db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Upload failed — check your connection and try again.', e);
    }
  }

  /// Best-effort content type from a file extension.
  static String mimeForExt(String ext) => switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'ppt' => 'application/vnd.ms-powerpoint',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'mp4' => 'video/mp4',
        _ => 'application/octet-stream',
      };

  /// Classify a resource by its extension for the ClassroomResource.kind.
  static String kindForExt(String ext) => switch (ext) {
        'pdf' => 'pdf',
        'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' => 'image',
        'mp4' || 'mov' || 'webm' => 'video',
        'pptx' || 'ppt' => 'pptx',
        _ => 'document',
      };
}
