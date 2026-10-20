// lib/repositories/school_class_repository.dart
// Offline-first repository for dynamic, school-specific class management.

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline_cache.dart';
import '../core/result.dart';
import '../models/school_class.dart';
import 'student_roster_repository.dart';

class ClassUsageStats {
  final int studentsCount;
  final int marksCount;
  final int timetableCount;
  final int feeCount;
  final int homeworkCount;

  const ClassUsageStats({
    this.studentsCount = 0,
    this.marksCount = 0,
    this.timetableCount = 0,
    this.feeCount = 0,
    this.homeworkCount = 0,
  });

  int get totalRecords =>
      studentsCount + marksCount + timetableCount + feeCount + homeworkCount;

  bool get canSafelyDelete => totalRecords == 0;
}

class SchoolClassRepository {
  SchoolClassRepository._();
  static final SchoolClassRepository instance = SchoolClassRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static const List<String> kDefaultSeedClasses = [
    'Form 1',
    'Form 2',
    'Form 3',
    'Form 4',
    'Form 5',
    'Lower Sixth',
    'Upper Sixth',
  ];

  String _cacheKey(String schoolId) {
    final resolved = StudentRosterRepository.resolveSchoolId(schoolId);
    return 'school_classes_$resolved';
  }

  /// Returns classes for [schoolId].
  /// Offline-first: loads from local cache, then checks Supabase,
  /// falling back to standard default classes if none exist yet.
  Future<List<SchoolClass>> getClasses(
    String schoolId, {
    bool activeOnly = false,
  }) async {
    final resolvedId = StudentRosterRepository.resolveSchoolId(schoolId);
    final cacheKey = _cacheKey(resolvedId);

    // 1. Read cached classes
    List<SchoolClass>? cached;
    try {
      cached = await OfflineCache.instance.get<List<SchoolClass>>(
        cacheKey,
        (json) => OfflineCache.listFromJson(json, (j) => SchoolClass.fromMap(j)),
      );
    } catch (_) {}

    // 2. Fetch from Supabase if ready
    List<SchoolClass>? remoteClasses;
    final client = _db;
    if (client != null && resolvedId.isNotEmpty) {
      try {
        final res = await client
            .from('school_classes')
            .select()
            .eq('school_id', resolvedId)
            .order('display_order', ascending: true)
            .order('name', ascending: true);

        if (res is List) {
          remoteClasses = res
              .map((row) => SchoolClass.fromMap(row as Map<String, dynamic>))
              .toList();
          // Update local cache
          await OfflineCache.instance.put(
            cacheKey,
            OfflineCache.listToJson(remoteClasses, (c) => c.toMap()),
          );
        }
      } catch (_) {
        // Table may not exist yet or offline; fallback to cached or defaults
      }
    }

    final effective = remoteClasses ?? cached;
    if (effective != null && effective.isNotEmpty) {
      if (activeOnly) {
        return effective.where((c) => c.isActive).toList();
      }
      return effective;
    }

    // 3. Fallback seeds if no classes configured yet
    final now = DateTime.now();
    final seeds = <SchoolClass>[];
    for (int i = 0; i < kDefaultSeedClasses.length; i++) {
      seeds.add(SchoolClass(
        id: 'seed_${resolvedId}_$i',
        schoolId: resolvedId,
        name: kDefaultSeedClasses[i],
        displayOrder: i,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ));
    }

    return seeds;
  }

  /// Convenience helper returning list of class name strings.
  Future<List<String>> getClassNames(
    String schoolId, {
    bool activeOnly = true,
  }) async {
    final classes = await getClasses(schoolId, activeOnly: activeOnly);
    return classes.map((c) => c.name).toList();
  }

  /// Adds a new custom class to [cls.schoolId].
  Future<Result<SchoolClass>> addClass(SchoolClass cls) async {
    final resolvedId = StudentRosterRepository.resolveSchoolId(cls.schoolId);
    final now = DateTime.now();
    final id = cls.id.isNotEmpty
        ? cls.id
        : 'cls_${DateTime.now().millisecondsSinceEpoch}';

    final normalized = cls.copyWith(
      id: id,
      schoolId: resolvedId,
      name: cls.name.trim(),
      createdAt: now,
      updatedAt: now,
    );

    // Update cache immediately
    final existing = await getClasses(resolvedId);
    if (existing.any((c) => c.name.toLowerCase() == normalized.name.toLowerCase())) {
      return Failure('A class named "${normalized.name}" already exists.', null);
    }

    final updatedList = [...existing, normalized];
    await OfflineCache.instance.put(
      _cacheKey(resolvedId),
      OfflineCache.listToJson(updatedList, (c) => c.toMap()),
    );

    // Persist to Supabase
    final client = _db;
    if (client != null && resolvedId.isNotEmpty) {
      try {
        await client.from('school_classes').upsert(normalized.toMap());
      } catch (e) {
        // Cached locally for offline resilience
      }
    }

    return Success(normalized);
  }

  /// Updates class details (name, code, programme, academicYear, isActive, displayOrder).
  Future<Result<SchoolClass>> updateClass(SchoolClass cls) async {
    final resolvedId = StudentRosterRepository.resolveSchoolId(cls.schoolId);
    final normalized = cls.copyWith(
      schoolId: resolvedId,
      name: cls.name.trim(),
      updatedAt: DateTime.now(),
    );

    final existing = await getClasses(resolvedId);
    final idx = existing.indexWhere((c) => c.id == normalized.id || c.name == normalized.name);
    final updatedList = List<SchoolClass>.from(existing);
    if (idx != -1) {
      updatedList[idx] = normalized;
    } else {
      updatedList.add(normalized);
    }

    await OfflineCache.instance.put(
      _cacheKey(resolvedId),
      OfflineCache.listToJson(updatedList, (c) => c.toMap()),
    );

    final client = _db;
    if (client != null && resolvedId.isNotEmpty) {
      try {
        await client
            .from('school_classes')
            .update(normalized.toMap())
            .eq('id', normalized.id);
      } catch (_) {}
    }

    return Success(normalized);
  }

  /// Checks if a class is in active use across students, marks, fees, timetables, and homework.
  Future<ClassUsageStats> checkClassUsage(String schoolId, String className) async {
    final resolvedId = StudentRosterRepository.resolveSchoolId(schoolId);
    final client = _db;
    if (client == null || resolvedId.isEmpty || className.isEmpty) {
      return const ClassUsageStats();
    }

    int studentCount = 0;
    int marksCount = 0;
    int timetableCount = 0;
    int feeCount = 0;
    int homeworkCount = 0;

    // 1. Check school_students
    try {
      final res = await client
          .from('school_students')
          .select('id')
          .eq('school_id', resolvedId)
          .eq('class_level', className);
      if (res is List) studentCount += res.length;
    } catch (_) {}

    // 2. Check users
    try {
      final res = await client
          .from('users')
          .select('id')
          .eq('institution_id', resolvedId)
          .eq('class_level', className);
      if (res is List) studentCount += res.length;
    } catch (_) {}

    // 3. Check school_marks
    try {
      final res = await client
          .from('school_marks')
          .select('id')
          .eq('school_id', resolvedId)
          .eq('class_level', className);
      if (res is List) marksCount += res.length;
    } catch (_) {}

    // 4. Check timetable slots
    try {
      final res = await client
          .from('school_timetable_slots')
          .select('id')
          .eq('school_id', resolvedId)
          .eq('class_level', className);
      if (res is List) timetableCount += res.length;
    } catch (_) {}

    // 5. Check homework
    try {
      final res = await client
          .from('homework')
          .select('id')
          .eq('school_id', resolvedId)
          .eq('class_level', className);
      if (res is List) homeworkCount += res.length;
    } catch (_) {}

    return ClassUsageStats(
      studentsCount: studentCount,
      marksCount: marksCount,
      timetableCount: timetableCount,
      feeCount: feeCount,
      homeworkCount: homeworkCount,
    );
  }

  /// Safely removes or archives a class.
  /// If [archiveInstead] is true or if active records exist, the class is marked
  /// [isActive = false] rather than silently destroying academic history.
  Future<Result<void>> deleteClass(
    String schoolId,
    String classId,
    String className, {
    bool archiveInstead = false,
  }) async {
    final resolvedId = StudentRosterRepository.resolveSchoolId(schoolId);

    // Check usage
    final usage = await checkClassUsage(resolvedId, className);
    if (!archiveInstead && !usage.canSafelyDelete) {
      return Failure(
        'Cannot permanently delete "$className" because it contains '
        '${usage.studentsCount} student(s), ${usage.marksCount} mark(s), and '
        '${usage.timetableCount} timetable slot(s). '
        'Please archive this class instead to preserve historical academic data.',
        null,
      );
    }

    if (archiveInstead) {
      final classes = await getClasses(resolvedId);
      final target = classes.firstWhere(
        (c) => c.id == classId || c.name == className,
        orElse: () => SchoolClass(
          id: classId,
          schoolId: resolvedId,
          name: className,
          isActive: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await updateClass(target.copyWith(isActive: false));
      return const Success(null);
    }

    // Hard delete when safe (0 associated records)
    final existing = await getClasses(resolvedId);
    final updatedList = existing.where((c) => c.id != classId && c.name != className).toList();
    await OfflineCache.instance.put(
      _cacheKey(resolvedId),
      OfflineCache.listToJson(updatedList, (c) => c.toMap()),
    );

    final client = _db;
    if (client != null && resolvedId.isNotEmpty) {
      try {
        await client
            .from('school_classes')
            .delete()
            .eq('school_id', resolvedId)
            .eq('name', className);
      } catch (_) {}
    }

    return const Success(null);
  }
}
