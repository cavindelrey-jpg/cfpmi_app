// lib/services/course_offline_service.dart
// Service for downloading entire marketplace courses and their lessons for
// offline access, tracking per-user lesson completion and overall progress.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_lesson.dart';
import '../models/public_course.dart';
import '../repositories/course_lesson_repository.dart';
import '../core/result.dart';
import '../data/local_database.dart';

class CourseOfflineService {
  CourseOfflineService._();
  static final CourseOfflineService instance = CourseOfflineService._();

  static const _offlineCourseIdsKey = 'offline_downloaded_course_ids';
  static const _offlineCourseMetaPrefix = 'offline_course_meta_';
  static const _offlineCourseLessonsPrefix = 'offline_course_lessons_';
  static const _completedLessonsPrefix = 'course_completed_lessons_';

  final StreamController<void> _changeNotifier = StreamController<void>.broadcast();
  final Map<String, StreamController<Set<String>>> _progressControllers = {};

  Stream<void> get changes => _changeNotifier.stream;

  /// Checks if [courseId] has been downloaded for offline reading.
  Future<bool> isCourseDownloaded(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_offlineCourseIdsKey) ?? const <String>[];
    if (!ids.contains(courseId)) return false;
    final meta = prefs.getString('$_offlineCourseMetaPrefix$courseId');
    return meta != null && meta.isNotEmpty;
  }

  /// Returns all downloaded courses available on this device.
  Future<List<PublicCourse>> getDownloadedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_offlineCourseIdsKey) ?? <String>[];
    final courses = <PublicCourse>[];
    final cleanIds = <String>[];

    for (final id in ids) {
      final meta = prefs.getString('$_offlineCourseMetaPrefix$id');
      if (meta != null && meta.isNotEmpty) {
        try {
          final json = jsonDecode(meta) as Map<String, dynamic>;
          courses.add(PublicCourse.fromSupabase(json));
          cleanIds.add(id);
        } catch (_) {}
      }
    }

    if (cleanIds.length != ids.length) {
      await prefs.setStringList(_offlineCourseIdsKey, cleanIds);
    }
    return courses;
  }

  /// Live stream of all downloaded courses on this device.
  Stream<List<PublicCourse>> watchDownloadedCourses() async* {
    yield await getDownloadedCourses();
    await for (final _ in _changeNotifier.stream) {
      yield await getDownloadedCourses();
    }
  }

  /// Downloads an entire course and all its lessons to local storage.
  /// Reports 0.0 to 1.0 download progress via [onProgress].
  Future<Result<void>> downloadCourse(
    PublicCourse course, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      final lessons = await CourseLessonRepository.instance.lessonsOnce(course.id);
      onProgress?.call(0.4);

      final prefs = await SharedPreferences.getInstance();

      // Cache cover image locally for offline display
      if (!kIsWeb && course.coverImageUrl != null && course.coverImageUrl!.isNotEmpty) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final courseDir = Directory('${dir.path}/offline_courses');
          if (!await courseDir.exists()) await courseDir.create(recursive: true);
          final file = File('${courseDir.path}/${course.id}_cover.jpg');
          final res = await http.get(Uri.parse(course.coverImageUrl!)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            await file.writeAsBytes(res.bodyBytes);
            await prefs.setString('offline_course_cover_${course.id}', file.path);
          }
        } catch (_) {}
      }

      // Serialize course with id
      final courseMap = course.toSupabase();
      courseMap['id'] = course.id;
      await prefs.setString('$_offlineCourseMetaPrefix${course.id}', jsonEncode(courseMap));
      onProgress?.call(0.7);

      // Serialize lessons
      final lessonList = lessons.map((l) {
        final m = l.toSupabase();
        m['id'] = l.id;
        return m;
      }).toList();
      await prefs.setString('$_offlineCourseLessonsPrefix${course.id}', jsonEncode(lessonList));
      onProgress?.call(0.9);

      final ids = prefs.getStringList(_offlineCourseIdsKey) ?? <String>[];
      if (!ids.contains(course.id)) {
        ids.add(course.id);
        await prefs.setStringList(_offlineCourseIdsKey, ids);
      }

      onProgress?.call(1.0);
      _changeNotifier.add(null);
      return const Success(null);
    } catch (e) {
      return Failure('Failed to download course for offline use.', e);
    }
  }

  /// Returns path to locally-cached course cover image, if downloaded.
  Future<String?> getCourseCoverPath(String courseId) async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('offline_course_cover_$courseId');
    if (path == null) return null;
    try {
      return File(path).existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// Removes a downloaded course and its cached lessons from the device.
  Future<void> deleteDownloadedCourse(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_offlineCourseMetaPrefix$courseId');
    await prefs.remove('$_offlineCourseLessonsPrefix$courseId');
    final coverPath = prefs.getString('offline_course_cover_$courseId');
    if (coverPath != null) {
      if (!kIsWeb) {
        try {
          final f = File(coverPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      await prefs.remove('offline_course_cover_$courseId');
    }
    final ids = prefs.getStringList(_offlineCourseIdsKey) ?? <String>[];
    if (ids.remove(courseId)) {
      await prefs.setStringList(_offlineCourseIdsKey, ids);
    }
    _changeNotifier.add(null);
  }

  /// Retrieves locally cached lessons for [courseId] when offline.
  Future<List<CourseLesson>> getOfflineLessons(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_offlineCourseLessonsPrefix$courseId');
    if (jsonStr == null || jsonStr.isEmpty) return const [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => CourseLesson.fromSupabase(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Gets the set of completed lesson IDs for [userId] in [courseId].
  Future<Set<String>> getCompletedLessonIds(String userId, String courseId) async {
    if (userId.isEmpty || courseId.isEmpty) return const <String>{};
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_completedLessonsPrefix${userId}_$courseId') ?? const <String>[];
    return list.toSet();
  }

  /// Stream of completed lesson IDs for [userId] in [courseId].
  Stream<Set<String>> watchCompletedLessonIds(String userId, String courseId) {
    final key = '${userId}_$courseId';
    if (!_progressControllers.containsKey(key)) {
      _progressControllers[key] = StreamController<Set<String>>.broadcast();
    }
    final ctrl = _progressControllers[key]!;

    return (() async* {
      yield await getCompletedLessonIds(userId, courseId);
      yield* ctrl.stream;
    })();
  }

  /// Toggles whether [lessonId] is marked as completed by [userId].
  Future<bool> toggleLessonCompleted(String userId, String courseId, String lessonId) async {
    if (userId.isEmpty || courseId.isEmpty || lessonId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_completedLessonsPrefix${userId}_$courseId';
    final current = (prefs.getStringList(key) ?? <String>[]).toSet();

    final isNowCompleted = !current.contains(lessonId);
    if (isNowCompleted) {
      current.add(lessonId);
    } else {
      current.remove(lessonId);
    }

    await prefs.setStringList(key, current.toList());

    final streamKey = '${userId}_$courseId';
    if (_progressControllers.containsKey(streamKey)) {
      _progressControllers[streamKey]!.add(current);
    }
    _changeNotifier.add(null);

    // Queue for automatic server synchronization when online
    try {
      final syncData = {
        'user_id': userId,
        'course_id': courseId,
        'lesson_id': lessonId,
        'completed': isNowCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await LocalDatabase.instance.queueSyncAction(
        'upsert',
        'course_lesson_completions',
        '${userId}_$lessonId',
        syncData,
      );
    } catch (_) {}

    return isNowCompleted;
  }

  /// Computes completion progress metrics for [courseId].
  Future<({int completed, int total, double percent})> getProgress(
    String userId,
    String courseId, {
    int? totalLessons,
  }) async {
    final completedSet = await getCompletedLessonIds(userId, courseId);
    int total = totalLessons ?? 0;
    if (total == 0) {
      final offlineLessons = await getOfflineLessons(courseId);
      total = offlineLessons.length;
    }
    if (total == 0 && courseId.isNotEmpty) {
      try {
        final remoteLessons = await CourseLessonRepository.instance.lessonsOnce(courseId);
        total = remoteLessons.length;
      } catch (_) {}
    }
    final completedCount = completedSet.length;
    if (total > 0 && completedCount > total) {
      total = completedCount;
    }
    final percent = total > 0 ? (completedCount / total).clamp(0.0, 1.0) : 0.0;
    return (completed: completedCount, total: total, percent: percent);
  }

  /// Reactive stream of completion progress for [courseId].
  Stream<({int completed, int total, double percent})> watchProgress(
    String userId,
    String courseId, {
    int? totalLessons,
  }) async* {
    yield await getProgress(userId, courseId, totalLessons: totalLessons);
    await for (final _ in watchCompletedLessonIds(userId, courseId)) {
      yield await getProgress(userId, courseId, totalLessons: totalLessons);
    }
  }

  /// Computes aggregate course progress across all active/enrolled/downloaded courses for [userId].
  Future<({int completedLessons, int totalLessons, int activeCourses, double percent})> getOverallProgress(
    String userId, {
    List<String> enrolledCourseIds = const [],
  }) async {
    if (userId.isEmpty) {
      return (completedLessons: 0, totalLessons: 0, activeCourses: 0, percent: 0.0);
    }
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_completedLessonsPrefix${userId}_';
    final courseIds = <String>{...enrolledCourseIds};

    // Include downloaded courses
    final downloadedIds = prefs.getStringList(_offlineCourseIdsKey) ?? const <String>[];
    courseIds.addAll(downloadedIds);

    // Include any course where user has completed at least one lesson
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        final cid = key.substring(prefix.length);
        final completed = prefs.getStringList(key) ?? const <String>[];
        if (cid.isNotEmpty && completed.isNotEmpty) {
          courseIds.add(cid);
        }
      }
    }

    courseIds.removeWhere((id) => id.trim().isEmpty);
    if (courseIds.isEmpty) {
      return (completedLessons: 0, totalLessons: 0, activeCourses: 0, percent: 0.0);
    }

    int totalCompleted = 0;
    int totalAvailable = 0;
    int activeCount = 0;

    for (final cid in courseIds) {
      final p = await getProgress(userId, cid);
      if (p.total > 0 || p.completed > 0) {
        activeCount++;
        totalCompleted += p.completed;
        totalAvailable += p.total > 0 ? p.total : p.completed;
      }
    }

    final percent = totalAvailable > 0
        ? (totalCompleted / totalAvailable).clamp(0.0, 1.0)
        : 0.0;
    return (
      completedLessons: totalCompleted,
      totalLessons: totalAvailable,
      activeCourses: activeCount,
      percent: percent,
    );
  }

  /// Reactive stream of aggregate course progress across active courses for [userId].
  Stream<({int completedLessons, int totalLessons, int activeCourses, double percent})> watchOverallProgress(
    String userId, {
    List<String> enrolledCourseIds = const [],
  }) async* {
    yield await getOverallProgress(userId, enrolledCourseIds: enrolledCourseIds);
    await for (final _ in _changeNotifier.stream) {
      yield await getOverallProgress(userId, enrolledCourseIds: enrolledCourseIds);
    }
  }
}
