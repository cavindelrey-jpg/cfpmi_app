// lib/repositories/classroom_repository.dart
// Academia Classroom backend. Live state (current_slide, status, resource
// visibility) is synced to all three views via supabase .stream() realtime
// (realtimeTolerant so a dropped channel never blanks the lesson). Backed by
// public.classroom_sessions / public.classroom_resources.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../core/realtime_tolerant.dart';
import '../models/classroom.dart';

class ClassroomRepository {
  ClassroomRepository._();
  static final ClassroomRepository instance = ClassroomRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _sessions => _db?.from('classroom_sessions');
  SupabaseQueryBuilder? get _resources => _db?.from('classroom_resources');

  // ── Session lifecycle ──────────────────────────────────────────────
  Future<Result<String>> createSession(ClassroomSession s) async {
    final t = _sessions;
    if (t == null) return const Failure('Classroom is offline right now.');
    try {
      final row = await t.insert(s.toInsertMap()).select('id').single();
      return Success(row['id'].toString());
    } catch (e) {
      return Failure('Could not create the class session.', e);
    }
  }

  Future<Result<void>> _patch(String id, Map<String, dynamic> data) async {
    final t = _sessions;
    if (t == null) return const Failure('Classroom is offline right now.');
    try {
      await t.update(data).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Could not update the class.', e);
    }
  }

  Future<Result<void>> startSession(String id) =>
      _patch(id, {'status': 'live', 'started_at': DateTime.now().toIso8601String()});

  Future<Result<void>> endSession(String id) =>
      _patch(id, {'status': 'ended', 'ended_at': DateTime.now().toIso8601String()});

  Future<Result<void>> setCurrentSlide(String id, int index) =>
      _patch(id, {'current_slide': index});

  Future<Result<void>> setSlides(String id, List<String> urls) =>
      _patch(id, {'slide_urls': urls});

  // ── Resources ──────────────────────────────────────────────────────
  Future<Result<void>> addResource(ClassroomResource r) async {
    final t = _resources;
    if (t == null) return const Failure('Classroom is offline right now.');
    try {
      await t.insert(r.toInsertMap());
      return const Success(null);
    } catch (e) {
      return Failure('Could not add the resource.', e);
    }
  }

  /// Change a resource's visibility — this is the teacher's RELEASE control.
  Future<Result<void>> setVisibility(String resourceId, ResourceVisibility v) async {
    final t = _resources;
    if (t == null) return const Failure('Classroom is offline right now.');
    try {
      await t.update({
        'visibility': v.wire,
        if (v == ResourceVisibility.released) 'released_at': DateTime.now().toIso8601String(),
      }).eq('id', resourceId);
      return const Success(null);
    } catch (e) {
      return Failure('Could not update the resource.', e);
    }
  }

  Future<Result<void>> deleteResource(String resourceId) async {
    final t = _resources;
    if (t == null) return const Failure('Classroom is offline right now.');
    try {
      await t.delete().eq('id', resourceId);
      return const Success(null);
    } catch (e) {
      return Failure('Could not remove the resource.', e);
    }
  }

  // ── Live subscriptions (realtime) ──────────────────────────────────
  /// Watch one session's live state — used by the teacher control, the TV
  /// display and the student view alike.
  Stream<ClassroomSession?> watchSession(String id) {
    final t = _sessions;
    if (t == null || id.isEmpty) return const Stream.empty();
    return t
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .realtimeTolerant()
        .map((rows) => rows.isEmpty ? null : ClassroomSession.fromMap(rows.first));
  }

  /// The session a student joins: the current live lesson for their class.
  Stream<ClassroomSession?> watchLiveForClass(String schoolId, String classLevel) {
    final t = _sessions;
    if (t == null || schoolId.isEmpty) return const Stream.empty();
    return t
        .stream(primaryKey: ['id'])
        .eq('school_id', schoolId)
        .realtimeTolerant()
        .map((rows) {
      final live = rows
          .map(ClassroomSession.fromMap)
          .where((s) => s.classLevel == classLevel && s.status == ClassroomStatus.live)
          .toList()
        ..sort((a, b) => (b.startedAt ?? DateTime(0)).compareTo(a.startedAt ?? DateTime(0)));
      return live.isEmpty ? null : live.first;
    });
  }

  Stream<List<ClassroomResource>> watchResources(String sessionId) {
    final t = _resources;
    if (t == null || sessionId.isEmpty) return const Stream.empty();
    return t
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .realtimeTolerant()
        .map((rows) {
      final list = rows.map(ClassroomResource.fromMap).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return list;
    });
  }

  /// Sessions a teacher has created (newest first) — the "Upcoming / recent"
  /// list on the teacher classroom home.
  Future<Result<List<ClassroomSession>>> listForTeacher(String schoolId, String teacherId) async {
    final t = _sessions;
    if (t == null) return const Failure('Classroom is offline right now.');
    try {
      final rows = await t
          .select()
          .eq('school_id', schoolId)
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false)
          .limit(50);
      return Success((rows as List).map((r) => ClassroomSession.fromMap(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Could not load your classes.', e);
    }
  }
}
