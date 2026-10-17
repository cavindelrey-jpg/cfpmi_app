// lib/features/courses_marketplace/course_lessons_page.dart
// Fifth tier: the lessons inside one Course (e.g. "Linear Equations" ->
// Introduction to Linear Equations, Solving Linear Equations, ...). This is
// where the user actually enters the learning content — see LessonReaderPage.
// Supports offline downloading, progress tracking, and offline cached lesson viewing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/course_lesson.dart';
import '../../models/public_course.dart';
import '../../repositories/course_lesson_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/course_offline_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart' show showToast;
import 'hierarchy_browse_scaffold.dart';
import 'lesson_reader_page.dart';

class CourseLessonsPage extends StatefulWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const CourseLessonsPage({super.key, required this.course, this.currentUser});

  @override
  State<CourseLessonsPage> createState() => _CourseLessonsPageState();
}

class _CourseLessonsPageState extends State<CourseLessonsPage> {
  bool _isDownloaded = false;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  late final Stream<List<CourseLesson>> _lessonsStream;

  @override
  void initState() {
    super.initState();
    _lessonsStream = CourseLessonRepository.instance.watchLessons(widget.course.id);
    if (widget.currentUser != null) {
      PublicCourseRepository.instance.recordCourseView(widget.course.id, widget.currentUser!.id);
    }
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final downloaded = await CourseOfflineService.instance.isCourseDownloaded(widget.course.id);
    if (mounted) setState(() => _isDownloaded = downloaded);
  }

  Future<void> _handleDownloadPress() async {
    if (_downloading) return;
    HapticFeedback.lightImpact();

    if (_isDownloaded) {
      final ac = AppColors.of(context);
      showModalBottomSheet(
        context: context,
        backgroundColor: ac.surf,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (bCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.offline_pin_rounded, color: ac.primary),
                title: const Text('Available Offline'),
                subtitle: const Text('This course is saved on your device.'),
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Re-download / Update'),
                onTap: () {
                  Navigator.pop(bCtx);
                  _startDownload();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: ac.red),
                title: Text('Remove from Offline', style: TextStyle(color: ac.red)),
                onTap: () async {
                  Navigator.pop(bCtx);
                  await CourseOfflineService.instance.deleteDownloadedCourse(widget.course.id);
                  if (mounted) {
                    setState(() => _isDownloaded = false);
                    showToast(context, 'Course removed from offline storage.');
                  }
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    await _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
    });

    final res = await CourseOfflineService.instance.downloadCourse(
      widget.course,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );

    if (!mounted) return;
    setState(() {
      _downloading = false;
      if (res is Success) _isDownloaded = true;
    });

    if (res is Success) {
      showToast(context, 'Course downloaded! Available offline anytime.');
    } else if (res is Failure) {
      showToast(context, (res as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final userId = widget.currentUser?.id ?? 'guest';

    return StreamBuilder<List<CourseLesson>>(
      stream: _lessonsStream,
      builder: (context, snap) {
        final lessons = snap.data ?? const <CourseLesson>[];
        final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;

        return StreamBuilder<Set<String>>(
          stream: CourseOfflineService.instance.watchCompletedLessonIds(userId, widget.course.id),
          builder: (context, progSnap) {
            final completedIds = progSnap.data ?? const <String>{};
            final total = lessons.length;
            final completed = completedIds.length;
            final pct = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

            final downloadAction = _downloading
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _downloadProgress > 0 ? _downloadProgress : null,
                          strokeWidth: 2.2,
                          color: ac.primary,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _isDownloaded ? Icons.offline_pin_rounded : Icons.download_for_offline_outlined,
                      color: _isDownloaded ? ac.primary : ac.txt2,
                    ),
                    tooltip: _isDownloaded ? 'Downloaded (Offline Ready)' : 'Download course for offline use',
                    onPressed: _handleDownloadPress,
                  );

            final progressBanner = total > 0
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: ac.surf,
                        borderRadius: BorderRadius.circular(Rad.sm),
                        border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (_isDownloaded) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ac.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.offline_pin_rounded, size: 12, color: ac.primary),
                                          const SizedBox(width: 4),
                                          Text('Offline Ready',
                                              style: AppText.caption.copyWith(
                                                  fontSize: 10, color: ac.primary, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text('Course Progress',
                                      style: AppText.bodySm.copyWith(fontWeight: FontWeight.w600, color: ac.txt)),
                                ],
                              ),
                              Text('$completed of $total lessons (${(pct * 100).toInt()}%)',
                                  style: AppText.caption.copyWith(color: ac.txt2, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: ac.surf3,
                              color: pct >= 1.0 ? ac.grn : ac.primary,
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null;

            return HierarchyBrowseScaffold<CourseLesson>(
              title: widget.course.title,
              subtitle: '${lessons.length} lesson${lessons.length == 1 ? '' : 's'}',
              searchHint: 'Search lessons…',
              loading: loading,
              items: lessons,
              actions: [downloadAction],
              headerWidget: progressBanner,
              searchableText: (l) => l.title,
              emptyMessage: 'No lessons have been added to this course yet.',
              gridTileBuilder: (context, lesson) => _LessonTile(
                lesson: lesson,
                isGrid: true,
                isCompleted: completedIds.contains(lesson.id),
                onTap: () => _open(context, lesson),
              ),
              listTileBuilder: (context, lesson) => _LessonTile(
                lesson: lesson,
                isGrid: false,
                isCompleted: completedIds.contains(lesson.id),
                onTap: () => _open(context, lesson),
              ),
            );
          },
        );
      },
    );
  }

  void _open(BuildContext context, CourseLesson lesson) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LessonReaderPage(course: widget.course, lesson: lesson, currentUser: widget.currentUser)));
  }
}

class _LessonTile extends StatelessWidget {
  final CourseLesson lesson;
  final bool isGrid;
  final bool isCompleted;
  final VoidCallback onTap;
  const _LessonTile({
    required this.lesson,
    required this.isGrid,
    this.isCompleted = false,
    required this.onTap,
  });

  String get _meta {
    final parts = <String>[];
    if (lesson.durationSeconds != null && lesson.durationSeconds! > 0) {
      final m = lesson.durationSeconds! ~/ 60;
      final s = lesson.durationSeconds! % 60;
      parts.add('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
    }
    parts.add('${lesson.viewCount} student${lesson.viewCount == 1 ? '' : 's'}');
    return parts.join(' • ');
  }

  // Mistake 1: wrap overlay icons in a frosted semi-transparent badge so they
  // don't disappear into the cover image.
  Widget _thumb(AppColors ac, {required double? size}) {
    final hasVideo = (lesson.videoUrl ?? '').isNotEmpty;
    final hasCover = (lesson.coverImageUrl ?? '').isNotEmpty;
    final imageChild = hasCover
        ? Image.network(
            lesson.coverImageUrl!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(ac, size),
          )
        : _fallback(ac, size);

    // Only add the overlay icon badge when there's an actual cover image to
    // contrast against — the fallback already shows the icon centred.
    final Widget content = hasCover
        ? Stack(
            alignment: Alignment.center,
            children: [
              imageChild,
              // Semi-transparent frosted badge (Mistake 1)
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(
                  hasVideo
                      ? Icons.play_circle_outline_rounded
                      : Icons.article_outlined,
                  color: Colors.white,
                  size: size != null ? 18 : 22,
                  semanticLabel: hasVideo ? 'Video lesson' : 'Article lesson',
                ),
              ),
            ],
          )
        : imageChild;

    return ClipRRect(borderRadius: BorderRadius.circular(10), child: content);
  }

  // Mistake 2: gradient fallback instead of a flat primaryBg colour.
  Widget _fallback(AppColors ac, double? size) {
    final hasVideo = (lesson.videoUrl ?? '').isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ac.primary.withValues(alpha: 0.8),
            ac.navy.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        hasVideo ? Icons.play_circle_outline_rounded : Icons.article_outlined,
        color: Colors.white.withValues(alpha: 0.85),
        size: 26,
        semanticLabel: hasVideo ? 'Video lesson' : 'Article lesson',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (isGrid) {
      return Material(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.md),
          onTap: onTap,
          child: Container(
            // Mistake 8: tighter bottom padding for better vertical balance.
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.md),
              // Mistake 7: softer border — ac.bdr with reduced alpha instead of bdr2.
              border: Border.all(color: isCompleted ? ac.grn.withValues(alpha: 0.6) : ac.bdr.withValues(alpha: 0.6), width: 0.8),
            ),
            child: Stack(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: SizedBox(width: double.infinity, child: _thumb(ac, size: null))),
                  const SizedBox(height: 6),
                  // Mistake 7: stronger title hierarchy via AppText.title.
                  Text(lesson.title,
                      style: AppText.title.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  // Mistake 6: proper "Course" badge instead of a plain caption.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ac.primaryBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Course',
                      style: AppText.label.copyWith(color: ac.primary, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_meta, style: AppText.caption.copyWith(fontSize: 10)),
                ]),
                if (isCompleted)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: ac.grn, shape: BoxShape.circle),
                      // Mistake 10: rounded icon variant + semantic label.
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white,
                          semanticLabel: 'Completed'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onTap,
        child: Container(
          // Mistake 3: consistent 16px horizontal, 12px vertical margins.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            // Mistake 7 (list): softer border consistent with grid tile.
            border: Border.all(color: isCompleted ? ac.grn.withValues(alpha: 0.6) : ac.bdr.withValues(alpha: 0.6), width: 0.8),
          ),
          child: Row(children: [
            _thumb(ac, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lesson.title,
                    style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_meta, style: AppText.caption.copyWith(fontSize: 11)),
              ]),
            ),
            if (isCompleted) ...[
              // Mistake 10: semantic label on status icon.
              Icon(Icons.check_circle_rounded, size: 18, color: ac.grn,
                  semanticLabel: 'Completed'),
              const SizedBox(width: 8),
            ],
            // Clear "open lesson" button so the way in is obvious.
            // Mistake 15: gradient CTA instead of flat primary colour.
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ac.primary, ac.navy2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              // Mistake 9: trust signal — show view count below action label.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon((lesson.videoUrl ?? '').isNotEmpty ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
                        size: 16, color: Colors.white,
                        semanticLabel: (lesson.videoUrl ?? '').isNotEmpty ? 'Play video' : 'Open article'),
                    const SizedBox(width: 5),
                    Text(isCompleted ? 'Review' : 'Open',
                        style: AppText.button.copyWith(fontSize: 12.5, color: Colors.white)),
                  ]),
                  if (lesson.viewCount > 0)
                    Text(
                      '${lesson.viewCount} enrolled',
                      style: const TextStyle(fontSize: 10, color: Colors.white70, height: 1.1),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
