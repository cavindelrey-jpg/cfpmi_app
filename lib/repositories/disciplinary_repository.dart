// lib/repositories/disciplinary_repository.dart
// Manages student disciplinary incident tracking with offline caching.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/offline_cache.dart';
import '../core/result.dart';
import '../models/disciplinary_record.dart';
import 'student_roster_repository.dart';

class DisciplinaryRepository {
  DisciplinaryRepository._();
  static final DisciplinaryRepository instance = DisciplinaryRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<Result<List<DisciplinaryRecord>>> getRecords(String schoolId, {String? classLevel}) async {
    final resolvedSchoolId = StudentRosterRepository.resolveSchoolId(schoolId);
    final cacheKey = 'disciplinary_${resolvedSchoolId}_${classLevel ?? 'all'}';

    try {
      final cached = await OfflineCache.instance.get<List<DisciplinaryRecord>>(
        cacheKey,
        (json) => OfflineCache.listFromJson(json, (j) => DisciplinaryRecord.fromMap(j)),
      );

      final list = await OfflineCache.instance.fetch<List<DisciplinaryRecord>>(
        cacheKey,
        () async {
          final db = _db;
          if (db != null) {
            try {
              var q = db.from('disciplinary_records').select().eq('school_id', resolvedSchoolId);
              if (classLevel != null && classLevel.isNotEmpty) {
                q = q.eq('class_level', classLevel);
              }
              final rows = await q.order('incident_date', ascending: false);
              return (rows as List)
                  .map((r) => DisciplinaryRecord.fromMap(r as Map<String, dynamic>))
                  .toList();
            } catch (_) {}
          }
          return cached ?? <DisciplinaryRecord>[];
        },
        toJson: (items) => OfflineCache.listToJson(items, (r) => r.toMap()),
        fromJson: (json) => OfflineCache.listFromJson(json, (j) => DisciplinaryRecord.fromMap(j)),
      );
      return Success(list);
    } catch (e) {
      return Failure('Could not load disciplinary records', e);
    }
  }

  Future<Result<void>> addRecord(DisciplinaryRecord record) async {
    final resolvedSchoolId = StudentRosterRepository.resolveSchoolId(record.schoolId);
    final normalized = DisciplinaryRecord(
      id: record.id,
      schoolId: resolvedSchoolId,
      studentId: record.studentId,
      studentName: record.studentName,
      classLevel: record.classLevel,
      incidentDate: record.incidentDate,
      infraction: record.infraction,
      severity: record.severity,
      actionTaken: record.actionTaken,
      parentContact: record.parentContact,
      parentNotified: record.parentNotified,
      resolved: record.resolved,
      reportedBy: record.reportedBy,
      notes: record.notes,
    );

    // 1. Immediately cache locally
    final keys = [
      'disciplinary_${resolvedSchoolId}_all',
      'disciplinary_${resolvedSchoolId}_${record.classLevel}',
    ];
    for (final key in keys) {
      final existing = await OfflineCache.instance.get<List<DisciplinaryRecord>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => DisciplinaryRecord.fromMap(j)),
      ) ?? [];
      final next = [normalized, ...existing.where((r) => r.id != normalized.id)];
      await OfflineCache.instance.put(
        key,
        OfflineCache.listToJson(next, (r) => r.toMap()),
      );
    }

    // 2. Try Supabase insert
    final db = _db;
    if (db != null) {
      try {
        await db.from('disciplinary_records').insert(normalized.toMap());
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<Result<void>> toggleResolved(String schoolId, String recordId, bool resolved) async {
    final resolvedSchoolId = StudentRosterRepository.resolveSchoolId(schoolId);
    final key = 'disciplinary_${resolvedSchoolId}_all';
    final existing = await OfflineCache.instance.get<List<DisciplinaryRecord>>(
      key,
      (json) => OfflineCache.listFromJson(json, (j) => DisciplinaryRecord.fromMap(j)),
    ) ?? [];
    final updated = existing.map((r) {
      if (r.id == recordId) {
        return DisciplinaryRecord(
          id: r.id,
          schoolId: r.schoolId,
          studentId: r.studentId,
          studentName: r.studentName,
          classLevel: r.classLevel,
          incidentDate: r.incidentDate,
          infraction: r.infraction,
          severity: r.severity,
          actionTaken: r.actionTaken,
          parentContact: r.parentContact,
          parentNotified: r.parentNotified,
          resolved: resolved,
          reportedBy: r.reportedBy,
          notes: r.notes,
        );
      }
      return r;
    }).toList();

    await OfflineCache.instance.put(
      key,
      OfflineCache.listToJson(updated, (r) => r.toMap()),
    );

    final db = _db;
    if (db != null) {
      try {
        await db.from('disciplinary_records').update({'resolved': resolved}).eq('id', recordId);
      } catch (_) {}
    }

    return const Success(null);
  }
}
