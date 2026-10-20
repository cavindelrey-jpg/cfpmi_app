// lib/features/courses_marketplace/topic_courses_page.dart
// Fourth tier: the actual courses inside one Level+Subject+Topic (e.g.
// Algebra -> Linear Equations, Quadratic Equations, ...).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/application_shell.dart';
import 'courses_home_page.dart';
import 'hierarchy_browse_scaffold.dart';
import 'level_subjects_page.dart';
import 'subject_topics_page.dart';
import 'course_lessons_page.dart';

class TopicCoursesPage extends StatefulWidget {
  final String level;
  final String subject;
  final String topic;
  final AppUser? user;
  const TopicCoursesPage({
    super.key, required this.level, required this.subject, required this.topic, this.user,
  });

  @override
  State<TopicCoursesPage> createState() => _TopicCoursesPageState();
}

class _TopicCoursesPageState extends State<TopicCoursesPage> {
  bool _loading = true;
  List<PublicCourse> _courses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final courses = await PublicCourseRepository.instance
        .coursesInTopic(widget.level, widget.subject, widget.topic);
    if (mounted) setState(() { _courses = courses; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return HierarchyBrowseScaffold<PublicCourse>(
      user: widget.user,
      navDestination: AppNavDestination.academicCourses,
      breadcrumbs: [
        ShellBreadcrumb(
          label: 'Courses',
          icon: Icons.menu_book_rounded,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CoursesHomePage(user: widget.user),
            ),
          ),
        ),
        ShellBreadcrumb(
          label: widget.level,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  LevelSubjectsPage(level: widget.level, user: widget.user),
            ),
          ),
        ),
        ShellBreadcrumb(
          label: widget.subject,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SubjectTopicsPage(
                level: widget.level,
                subject: widget.subject,
                user: widget.user,
              ),
            ),
          ),
        ),
        ShellBreadcrumb(label: widget.topic),
      ],
      title: widget.topic,
      subtitle: '${_courses.length} course${_courses.length == 1 ? '' : 's'}',
      searchHint: 'Search courses…',
      loading: _loading,
      items: _courses,
      searchableText: (c) => c.title,
      emptyMessage: 'No courses in this topic yet.',
      gridTileBuilder: (context, course) => _CourseTile(course: course, isGrid: true, onTap: () => _open(context, course)),
      listTileBuilder: (context, course) => _CourseTile(course: course, isGrid: false, onTap: () => _open(context, course)),
    );
  }

  void _open(BuildContext context, PublicCourse course) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CourseLessonsPage(course: course, currentUser: widget.user)));
  }
}

class _CourseTile extends StatelessWidget {
  final PublicCourse course;
  final bool isGrid;
  final VoidCallback onTap;
  const _CourseTile({required this.course, required this.isGrid, required this.onTap});

  Widget _thumb(AppColors ac, {required double? size}) {
    final hasCover = (course.coverImageUrl ?? '').isNotEmpty;
    final child = hasCover
        ? Image.network(course.coverImageUrl!, fit: BoxFit.cover,
            width: size, height: size, errorBuilder: (_, __, ___) => _fallbackThumb(ac, size))
        : _fallbackThumb(ac, size);
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: child);
  }

  Widget _fallbackThumb(AppColors ac, double? size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ac.primary.withValues(alpha: .8), ac.navy.withValues(alpha: .9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_rounded, color: Colors.white.withValues(alpha: .9), size: 26));

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
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr.withValues(alpha: 0.6), width: 0.8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: SizedBox(width: double.infinity, child: _thumb(ac, size: null))),
              const SizedBox(height: 6),
              Text(course.title, style: AppText.title.copyWith(fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ac.primaryBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Course', style: AppText.label.copyWith(color: ac.primary, letterSpacing: 0.6)),
              ),
            ]),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr.withValues(alpha: 0.6), width: 0.8),
          ),
          child: Row(children: [
            _thumb(ac, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(course.title, style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  course.creatorName.isNotEmpty ? course.creatorName : 'Course',
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ac.primaryBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Open', style: AppText.label.copyWith(color: ac.primary, letterSpacing: 0.3)),
            ),
          ]),
        ),
      ),
    );
  }
}
