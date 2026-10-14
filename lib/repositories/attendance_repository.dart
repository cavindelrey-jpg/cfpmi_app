// lib/repositories/attendance_repository.dart
// Daily student attendance. Backed by public.attendance_records (see
// supabase/migrations/20261014120000_attendance_records.sql) — one row per
// (school, class, date, student, subject). saveBatch() upserts on that
// tuple so re-saving a register corrects rows rather than duplicating them.
// Follows the same Supabase + Result idiom as StudentRosterRepository /
// SchoolMarksRepository.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../models/attendance_record.dart';

class AttendanceRepository {
  AttendanceRepository._();
  static final AttendanceRepository instance = AttendanceRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _table => _db?.from('attendance_records');

  /// Existing attendance for one class on one date (optionally one subject).
  Future<Result<List<AttendanceRecord>>> getForClassDate(
    String schoolId,
    String classLevel,
    DateTime date, {
    String subject = '',
  }) async {
    if (schoolId.isEmpty || classLevel.isEmpty) return const Success([]);
    final table = _table;
    if (table == null) return const Failure('Attendance is offline right now.');
    try {
      final rows = await table
          .select()
          .eq('school_id', schoolId)
          .eq('class_level', classLevel)
          .eq('session_date', AttendanceRecord.dateKey(date))
          .eq('subject', subject);
      final list = (rows as List)
          .map((r) => AttendanceRecord.fromMap(r as Map<String, dynamic>))
          .toList();
      return Success(list);
    } catch (e) {
      return Failure('Could not load attendance.', e);
    }
  }

  /// Upsert a whole register for a class/date in one call. No-op on empty.
  Future<Result<void>> saveBatch(List<AttendanceRecord> records) async {
    if (records.isEmpty) return const Success(null);
    final table = _table;
    if (table == null) return const Failure('Attendance is offline right now.');
    try {
      await table.upsert(
        records.map((r) => r.toMap()).toList(),
        onConflict: 'school_id,class_level,session_date,student_id,subject',
      );
      return const Success(null);
    } catch (e) {
      return Failure('Could not save attendance.', e);
    }
  }

  /// All attendance for a class across a date range — for the staff monitor.
  Future<Result<List<AttendanceRecord>>> getForClassRange(
    String schoolId,
    String classLevel,
    DateTime from,
    DateTime to,
  ) async {
    if (schoolId.isEmpty || classLevel.isEmpty) return const Success([]);
    final table = _table;
    if (table == null) return const Failure('Attendance is offline right now.');
    try {
      final rows = await table
          .select()
          .eq('school_id', schoolId)
          .eq('class_level', classLevel)
          .gte('session_date', AttendanceRecord.dateKey(from))
          .lte('session_date', AttendanceRecord.dateKey(to));
      final list = (rows as List)
          .map((r) => AttendanceRecord.fromMap(r as Map<String, dynamic>))
          .toList();
      return Success(list);
    } catch (e) {
      return Failure('Could not load attendance.', e);
    }
  }

  /// A single student's attendance history (most recent first).
  Future<Result<List<AttendanceRecord>>> getForStudent(
    String studentId, {
    int limit = 180,
  }) async {
    if (studentId.isEmpty) return const Success([]);
    final table = _table;
    if (table == null) return const Failure('Attendance is offline right now.');
    try {
      final rows = await table
          .select()
          .eq('student_id', studentId)
          .order('session_date', ascending: false)
          .limit(limit);
      final list = (rows as List)
          .map((r) => AttendanceRecord.fromMap(r as Map<String, dynamic>))
          .toList();
      return Success(list);
    } catch (e) {
      return Failure('Could not load attendance.', e);
    }
  }
}
