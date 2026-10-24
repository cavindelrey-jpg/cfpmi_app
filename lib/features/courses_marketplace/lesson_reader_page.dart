// lib/features/courses_marketplace/lesson_reader_page.dart
// Where the user actually consumes content: video (or quill text) for one
// lesson, plus Overview/Resources/Notes/Comments tabs. Course-level actions
// (rating, like, bookmark, share, prerequisites, comments) live here rather
// than on a separate course page — a course itself has no content of its
// own anymore, only its lessons do.
//
// Video lessons stay gated Premium Gold-only for READERS, same rule the
// old course-level video had (core/feature_access.dart#AppFeature.
// coursesVideoLessons, the single place this gate is decided) — see
// _LockedVideoCard below, ported from course_reader_page.dart's
// _VideoLessonSection.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import '../../core/feature_access.dart';
import '../../models/app_user.dart';
import '../../models/course_lesson.dart';
import '../../models/entitlement.dart';
import '../../models/public_course.dart';
import '../../repositories/course_lesson_repository.dart';
import '../../repositories/public_course_repository.dart';
import '../../services/course_offline_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/application_shell.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/formula_embed_builder.dart';
import '../../widgets/media_players.dart';
import '../../widgets/premium_unlock_sheet.dart';
import 'course_creator_profile_page.dart';
import 'course_lessons_page.dart';
import 'courses_home_page.dart';
import 'lesson_composer_page.dart';

import '../../widgets/skeleton_spinner.dart';
class LessonReaderPage extends StatefulWidget {
  final PublicCourse course;
  final CourseLesson lesson;
  final AppUser? currentUser;
  const LessonReaderPage({super.key, required this.course, required this.lesson, this.currentUser});

  @override
  State<LessonReaderPage> createState() => _LessonReaderPageState();
}

class _LessonReaderPageState extends State<LessonReaderPage> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 4, vsync: this);
  final _commentCtrl = TextEditingController();
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    CourseLessonRepository.instance.incrementView(widget.lesson.id);
    final user = widget.currentUser;
    if (user != null) {
      PublicCourseRepository.instance.markEnrolled(widget.course.id, user.id);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final user = widget.currentUser;
    final body = _commentCtrl.text.trim();
    if (user == null || body.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _postingComment = true);
    await PublicCourseRepository.instance.postComment(CourseComment(
      id: '', courseId: widget.course.id,
      authorId: user.id, authorName: user.name, authorPhotoUrl: user.photoUrl,
      body: body,
    ));
    _commentCtrl.clear();
    if (mounted) setState(() => _postingComment = false);
  }

  Future<void> _continue(BuildContext context) async {
    final adjacent = await CourseLessonRepository.instance.adjacentTo(widget.course.id, widget.lesson.id);
    if (!context.mounted) return;
    if (adjacent.next != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => LessonReaderPage(course: widget.course, lesson: adjacent.next!, currentUser: widget.currentUser)));
    } else {
      Navigator.of(context).pop();
    }
  }

  // Human-readable lesson length from a duration in seconds.
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '$m min';
    return '$m min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final lesson = widget.lesson;
    final hasVideo = (lesson.videoUrl ?? '').isNotEmpty;
    final userId = widget.currentUser?.id ?? 'guest';
    final canEdit = widget.currentUser != null &&
        !widget.currentUser!.isGuest &&
        (widget.currentUser!.id == widget.course.creatorId || widget.currentUser!.isSuperAdmin);
    return ApplicationShell(
      user: widget.currentUser,
      currentTitle: lesson.title,
      subtitle: widget.course.title,
      currentDestination: AppNavDestination.academicCourses,
      breadcrumbs: [
        ShellBreadcrumb(
          label: 'Courses',
          icon: Icons.menu_book_rounded,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CoursesHomePage(user: widget.currentUser),
            ),
          ),
        ),
        ShellBreadcrumb(
          label: widget.course.title,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CourseLessonsPage(
                course: widget.course,
                currentUser: widget.currentUser,
              ),
            ),
          ),
        ),
        ShellBreadcrumb(label: lesson.title),
      ],
      headerActions: [
        IconButton(
          icon: Icon(Icons.copy_rounded, size: 20, color: ac.txt2),
          tooltip: 'Copy lesson text',
          onPressed: () {
            HapticFeedback.selectionClick();
            final text = _extractPlainText(lesson);
            Clipboard.setData(ClipboardData(text: '${lesson.title}\n\n$text'));
            showToast(context, 'Lesson text copied to clipboard.');
          },
        ),
        if (canEdit)
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: ac.txt2),
            tooltip: 'Edit lesson',
            onPressed: () async {
              final allLessons = await CourseLessonRepository.instance
                  .lessonsOnce(widget.course.id);
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonComposerPage(
                    user: widget.currentUser!,
                    courseId: widget.course.id,
                    existing: lesson,
                    existingSequence: allLessons,
                  ),
                ),
              );
            },
          ),
      ],
      contextualPanel: CoursesContextualPanel(
        user: widget.currentUser ?? AppUser.guest(),
        activeCourse: widget.course,
        activeLessonId: lesson.id,
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: _readerColumn(ac, lesson, hasVideo),
              ),
            ),
          ),
          // Sticky bottom action area — stays visible while the learner scrolls
          Container(
            decoration: BoxDecoration(
              color: ac.surf,
              border: Border(
                top: BorderSide(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
              ),
              boxShadow: Shad.sm,
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: StreamBuilder<Set<String>>(
                  stream: CourseOfflineService.instance
                      .watchCompletedLessonIds(userId, widget.course.id),
                  builder: (context, cSnap) {
                    final completed = cSnap.data?.contains(lesson.id) ?? false;
                    return Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: completed ? ac.grn : ac.primary,
                            side: BorderSide(
                              color: completed ? ac.grn : ac.primary,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            completed
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: completed ? ac.grn : ac.primary,
                          ),
                          label: Text(
                            completed ? 'Completed' : 'Complete',
                            style: AppText.subtitle.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: completed ? ac.grn : ac.primary,
                            ),
                          ),
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final nowDone = await CourseOfflineService.instance
                                .toggleLessonCompleted(
                              userId,
                              widget.course.id,
                              lesson.id,
                            );
                            if (context.mounted) {
                              showToast(
                                context,
                                nowDone
                                    ? 'Lesson marked as completed!'
                                    : 'Lesson marked as incomplete.',
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryBtn(
                            label: completed
                                ? 'Next Lesson'
                                : 'Mark Complete & Continue',
                            icon: Icons.arrow_forward_rounded,
                            onTap: () async {
                              if (!completed) {
                                await CourseOfflineService.instance
                                    .toggleLessonCompleted(
                                  userId,
                                  widget.course.id,
                                  lesson.id,
                                );
                              }
                              if (context.mounted) {
                                _continue(context);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The reading column: lesson title, video (if any), tabbed content.
  Widget _readerColumn(AppColors ac, CourseLesson lesson, bool hasVideo) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(lesson.title,
              style: AppText.h1.copyWith(fontSize: 24, color: ac.txt, height: 1.2)),
        ),
      ),
      // Trust signals near title: view count + duration (Mistake 9)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Row(children: [
          Icon(Icons.people_outline_rounded, size: 14, color: ac.muted),
          const SizedBox(width: 4),
          Text('${lesson.viewCount} students', style: AppText.caption),
          if (lesson.durationSeconds != null && lesson.durationSeconds! > 0) ...[ 
            const SizedBox(width: 12),
            Icon(Icons.schedule_rounded, size: 14, color: ac.muted),
            const SizedBox(width: 4),
            Text(_formatDuration(lesson.durationSeconds!), style: AppText.caption),
          ],
        ]),
      ),
      if (hasVideo)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _LockedVideoCard(lesson: lesson, currentUser: widget.currentUser),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TabBar(
          controller: _tabCtrl,
          isScrollable: false,
          labelColor: ac.primary, unselectedLabelColor: ac.muted,
          indicatorColor: ac.primary,
          labelStyle: AppText.subtitle.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppText.subtitle.copyWith(fontSize: 13),
          tabs: const [
            Tab(text: 'Overview'), Tab(text: 'Resources'), Tab(text: 'Notes'), Tab(text: 'Comments'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabCtrl, children: [
          _OverviewTab(course: widget.course, lesson: lesson, hasVideo: hasVideo, currentUser: widget.currentUser,
              onContinue: () => _continue(context)),
          _ResourcesTab(course: widget.course, lesson: lesson),
          _NotesTab(lesson: lesson, userId: widget.currentUser?.id ?? 'guest'),
          _CommentsTab(
            course: widget.course, currentUser: widget.currentUser,
            commentCtrl: _commentCtrl, posting: _postingComment, onPost: _postComment,
          ),
        ]),
      ),
    ]);
  }

  // Desktop contextual panel: the course's lessons as a table of contents,
  // current lesson highlighted; tapping another opens it in place.
  Widget _contextPanel(AppColors ac, CourseLesson lesson) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 14, 8, 16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          child: Text('In this course', style: AppText.h2.copyWith(fontSize: 15, color: ac.txt)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(widget.course.title,
              style: AppText.caption.copyWith(fontSize: 11.5, color: ac.txt2),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        Divider(height: 1, thickness: 0.8, color: ac.bdr.withValues(alpha: 0.7)),
        Expanded(
          child: FutureBuilder<List<CourseLesson>>(
            future: CourseLessonRepository.instance.lessonsOnce(widget.course.id),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: List.generate(5, (_) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: ShimmerLine(height: 16),
                  )),
                );
              }
              final lessons = snap.data ?? const <CourseLesson>[];
              if (lessons.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No other lessons yet.', style: AppText.bodySm.copyWith(color: ac.txt2)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: lessons.length,
                itemBuilder: (_, i) => _tocRow(ac, lessons[i], i + 1, lessons[i].id == lesson.id),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _tocRow(AppColors ac, CourseLesson l, int number, bool current) {
    final isVideo = (l.videoUrl ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: current ? ac.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: current
              ? null
              : () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => LessonReaderPage(course: widget.course, lesson: l, currentUser: widget.currentUser))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22, height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current ? ac.primary : ac.surf2,
                  shape: BoxShape.circle,
                  border: current ? null : Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
                ),
                child: Text('$number',
                    style: AppText.label.copyWith(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: current ? Colors.white : ac.txt2)),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 5),
                child: Icon(
                  isVideo ? Icons.play_circle_outline_rounded : Icons.article_outlined,
                  size: 13,
                  color: current ? ac.primary : ac.muted,
                ),
              ),
              Expanded(
                child: Text(l.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(
                        fontSize: 13,
                        letterSpacing: current ? -0.1 : 0,
                        color: current ? ac.txt : ac.txt2,
                        fontWeight: current ? FontWeight.w700 : FontWeight.w500)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

String _extractPlainText(CourseLesson lesson) {
  final deltaJson = lesson.bodyDelta;
  if (deltaJson != null && deltaJson.isNotEmpty) {
    try {
      final doc = quill.Document.fromJson(jsonDecode(deltaJson));
      final plain = doc.toPlainText().trim();
      if (plain.isNotEmpty) return plain;
    } catch (_) {}
  }
  return lesson.body.trim();
}

/// Video lessons stay gated Premium Gold-only for readers — Silver and
/// Free/Guest both see the same locked card; only the CTA copy differs
/// (upgrade vs. sign in first). Ported from course_reader_page.dart's
/// _VideoLessonSection, now scoped per-lesson instead of per-course.
class _LockedVideoCard extends StatelessWidget {
  final CourseLesson lesson;
  final AppUser? currentUser;
  const _LockedVideoCard({required this.lesson, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final url = lesson.videoUrl!;
    if (FeatureAccess.canAccess(currentUser, AppFeature.coursesVideoLessons)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Rad.md),
        child: ArticleVideoPlayer(url: url),
      );
    }
    final signedIn = currentUser != null && !currentUser!.isGuest;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.goldBg,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.gold.withValues(alpha: .25)),
      ),
      child: Row(children: [
        Icon(Icons.lock_rounded, color: ac.gold, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Video Lesson — Premium Gold', style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text(FeatureAccess.reasonBlocked(currentUser, AppFeature.coursesVideoLessons),
              style: AppText.caption.copyWith(fontSize: 11.5)),
        ])),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            if (!signedIn) {
              Navigator.of(context).pop();
              return;
            }
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: ac.surf,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
              builder: (_) => PremiumUnlockSheet(
                userId: currentUser!.id,
                initialTier: EntitlementTier.gold,
                onUnlockSuccess: () {},
              ),
            );
          },
          child: Text(signedIn ? 'Upgrade' : 'Sign in'),
        ),
      ]),
    );
  }
}

class _ResourcesTab extends StatelessWidget {
  final PublicCourse course;
  final CourseLesson lesson;
  const _ResourcesTab({required this.course, required this.lesson});

  List<String> _extractUrls(String text) {
    final regex = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
    return regex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final plainText = _extractPlainText(lesson);
    final urls = <String>{
      if ((lesson.videoUrl ?? '').isNotEmpty) lesson.videoUrl!,
      ..._extractUrls(plainText),
      ..._extractUrls(course.description),
    }.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.content_copy_rounded, size: 18, color: ac.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Lesson Text & Transcript',
                        style: AppText.title.copyWith(fontSize: 14, color: ac.txt)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                plainText.isNotEmpty
                    ? '${plainText.split(RegExp(r'\s+')).length} words · Copy full lesson text to clipboard or paste into your Notes.'
                    : 'Copy lesson title and summary to clipboard.',
                style: AppText.caption.copyWith(fontSize: 12, color: ac.txt2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final copyStr = plainText.isNotEmpty
                          ? '${lesson.title}\n\n$plainText'
                          : '${lesson.title}\n\n${course.description}';
                      Clipboard.setData(ClipboardData(text: copyStr));
                      showToast(context, 'Lesson text copied to clipboard.');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                    label: Text('Copy Lesson Text',
                        style: AppText.button.copyWith(fontSize: 12.5, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      final copyStr = plainText.isNotEmpty
                          ? '${lesson.title}\n\n$plainText'
                          : lesson.title;
                      Share.share(copyStr);
                    },
                    icon: Icon(Icons.share_outlined, size: 16, color: ac.txt),
                    label: Text('Share', style: AppText.subtitle.copyWith(fontSize: 12.5, color: ac.txt)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      side: BorderSide(color: ac.bdr),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Links & References', style: AppText.h2.copyWith(fontSize: 15, color: ac.txt)),
        const SizedBox(height: 8),
        if (urls.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ac.surf2,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
            ),
            child: Text(
              'No external web links attached to this lesson.',
              style: AppText.bodySm.copyWith(color: ac.txt2),
            ),
          )
        else
          ...urls.map((u) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: ac.surf,
                  borderRadius: BorderRadius.circular(Rad.sm),
                  border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
                ),
                child: ListTile(
                  leading: Icon(Icons.link_rounded, color: ac.primary),
                  title: Text(u,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: ac.primary, fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy_rounded, size: 18, color: ac.txt2),
                        tooltip: 'Copy link',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: u));
                          showToast(context, 'Link copied to clipboard.');
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.open_in_new_rounded, size: 18, color: ac.primary),
                        tooltip: 'Open link',
                        onPressed: () async {
                          final uri = Uri.tryParse(u);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _NotesTab extends StatefulWidget {
  final CourseLesson lesson;
  final String userId;
  const _NotesTab({required this.lesson, required this.userId});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  final _notesCtrl = TextEditingController();
  bool _loaded = false;

  String get _prefsKey => 'lesson_notes_${widget.userId}_${widget.lesson.id}';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? '';
    if (!mounted) return;
    setState(() {
      _notesCtrl.text = saved;
      _loaded = true;
    });
  }

  Future<void> _saveNotes(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, val);
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (!_loaded) {
      return const Center(child: SkeletonSpinner());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Personal Study Notes',
                  style: AppText.h2.copyWith(fontSize: 15, color: ac.txt)),
            ),
            TextButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text;
                if (text == null || text.isEmpty) {
                  if (context.mounted) showToast(context, 'Clipboard is empty.');
                  return;
                }
                final next = _notesCtrl.text.isEmpty ? text : '${_notesCtrl.text}\n$text';
                setState(() => _notesCtrl.text = next);
                await _saveNotes(next);
                if (context.mounted) showToast(context, 'Pasted into notes.');
              },
              icon: Icon(Icons.content_paste_rounded, size: 15, color: ac.primary),
              label: Text('Paste', style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.primary)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: () {
                if (_notesCtrl.text.trim().isEmpty) {
                  showToast(context, 'No notes to copy yet.');
                  return;
                }
                Clipboard.setData(ClipboardData(text: _notesCtrl.text));
                showToast(context, 'Notes copied to clipboard.');
              },
              icon: Icon(Icons.copy_rounded, size: 15, color: ac.txt2),
              label: Text('Copy', style: AppText.caption.copyWith(fontWeight: FontWeight.w600, color: ac.txt2)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: () async {
                final lessonText = _extractPlainText(widget.lesson);
                if (lessonText.isEmpty) {
                  showToast(context, 'No lesson text to quote.');
                  return;
                }
                final next = _notesCtrl.text.isEmpty
                    ? lessonText
                    : '${_notesCtrl.text}\n\n$lessonText';
                setState(() => _notesCtrl.text = next);
                await _saveNotes(next);
                if (context.mounted) showToast(context, 'Lesson text added to your notes.');
              },
              icon: Icon(Icons.note_add_outlined, size: 15, color: ac.primary),
              label: Text('Insert Lesson Text',
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.primary)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 12,
          minLines: 8,
          onChanged: _saveNotes,
          style: AppText.body.copyWith(fontSize: 14.5, color: ac.txt, height: 1.6),
          decoration: InputDecoration(
            hintText: 'Type or paste your notes for "${widget.lesson.title}" here — saved automatically on your device…',
            hintStyle: AppText.bodySm.copyWith(color: ac.muted),
            filled: true,
            fillColor: ac.surf,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Rad.md),
              borderSide: BorderSide(color: ac.bdr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Rad.md),
              borderSide: BorderSide(color: ac.bdr),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Rad.md),
              borderSide: BorderSide(color: ac.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final PublicCourse course;
  final CourseLesson lesson;
  final bool hasVideo;
  final AppUser? currentUser;
  final VoidCallback onContinue;
  const _OverviewTab({
    required this.course, required this.lesson, required this.hasVideo,
    required this.currentUser, required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasBodyText = lesson.body.trim().isNotEmpty || (lesson.bodyDelta ?? '').isNotEmpty;
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (!hasVideo || hasBodyText) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lesson Content', style: AppText.caption.copyWith(color: ac.muted, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: () {
                    final text = _extractPlainText(lesson);
                    Clipboard.setData(ClipboardData(text: '${lesson.title}\n\n$text'));
                    showToast(context, 'Lesson text copied to clipboard.');
                  },
                  icon: Icon(Icons.copy_rounded, size: 14, color: ac.primary),
                  label: Text('Copy Text', style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _LessonBody(lesson: lesson),
            const SizedBox(height: 20),
            Divider(height: 1, thickness: 0.8, color: ac.bdr.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
          ],
          Text('About this lesson', style: AppText.h2.copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text(course.description.isNotEmpty ? course.description : 'No description provided.',
              style: AppText.bodySm.copyWith(fontSize: 13.5, height: 1.6, color: ac.txt2)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (lesson.durationSeconds != null && lesson.durationSeconds! > 0)
              _MetaPill(icon: Icons.schedule_rounded, label: 'Duration', value: _durationLabel(lesson.durationSeconds!)),
            if (course.level.isNotEmpty)
              _MetaPill(icon: Icons.school_outlined, label: 'Level', value: course.level),
            _MetaPill(icon: Icons.visibility_outlined, label: 'Viewers', value: '${lesson.viewCount}'),
            _MetaPill(icon: Icons.update_rounded, label: 'Last updated', value: _dateLabel(lesson.updatedAt)),
          ]),
          const SizedBox(height: 20),
          Divider(height: 1, thickness: 0.8, color: ac.bdr.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          _CourseInfoRow(course: course, currentUser: currentUser),
          if (course.prerequisiteIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PrerequisitesLinks(course: course, currentUser: currentUser),
          ],
          const SizedBox(height: 20),
          _ActionRow(course: course, currentUser: currentUser),
        ],
      ),
    );
  }

  static String _durationLabel(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _dateLabel(DateTime d) => '${_month(d.month)} ${d.day}, ${d.year}';
  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

class _LessonBody extends StatelessWidget {
  final CourseLesson lesson;
  const _LessonBody({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final deltaJson = lesson.bodyDelta;
    if (deltaJson == null || deltaJson.isEmpty) {
      return SelectableText(lesson.body, style: AppText.body);
    }
    quill.QuillController controller;
    try {
      final doc = quill.Document.fromJson(jsonDecode(deltaJson));
      controller = quill.QuillController(
        document: doc, selection: const TextSelection.collapsed(offset: 0), readOnly: true,
      );
    } catch (_) {
      return SelectableText(lesson.body, style: AppText.body);
    }
    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        showCursor: false, autoFocus: false, placeholder: 'Lesson content…',
        enableInteractiveSelection: true,
        embedBuilders: [...FlutterQuillEmbeds.editorBuilders(), const FormulaEmbedBuilder()],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: ac.muted),
          const SizedBox(width: 4),
          Text(label, style: AppText.caption.copyWith(fontSize: 10)),
        ]),
        const SizedBox(height: 2),
        Text(value, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w700, fontSize: 12.5)),
      ]),
    );
  }
}

class _CourseInfoRow extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _CourseInfoRow({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<PublicCourse?>(
      stream: PublicCourseRepository.instance.watchOne(course.id),
      initialData: course,
      builder: (context, snap) {
        final c = snap.data ?? course;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.sm),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseCreatorProfilePage(creatorId: c.creatorId, currentUser: currentUser))),
              child: Row(children: [
                UserAvatar(initials: c.creatorName.isEmpty ? '?' : c.creatorName[0].toUpperCase(),
                    radius: 16, photoUrl: c.creatorPhotoUrl),
                const SizedBox(width: 10),
                Text(c.creatorName, style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 13)),
                const Spacer(),
                Icon(Icons.people_alt_outlined, size: 14, color: ac.muted),
                const SizedBox(width: 4),
                Text('${c.enrolledCount} learners', style: AppText.caption),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Row(children: List.generate(5, (i) => Icon(
              i < c.avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18, color: ac.gold,
            ))),
            const SizedBox(width: 8),
            Text(c.avgRating > 0 ? c.avgRating.toStringAsFixed(1) : 'No ratings yet',
                style: AppText.subtitle.copyWith(color: ac.txt, fontSize: 13)),
            if (c.ratingCount > 0) Text(' (${c.ratingCount})', style: AppText.caption),
            const Spacer(),
            if (currentUser != null && currentUser!.id != c.creatorId)
              TextButton(
                onPressed: () => _showRateSheet(context, c),
                child: Text('Rate this course', style: AppText.caption.copyWith(
                    fontSize: 12, fontWeight: FontWeight.w700, color: ac.primary)),
              ),
          ]),
        ]);
      },
    );
  }

  void _showRateSheet(BuildContext context, PublicCourse course) {
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (dCtx, setM) {
        int selected = 5;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Rate this course', style: AppText.title.copyWith(fontSize: 16)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
                IconButton(
                  icon: Icon(i < selected ? Icons.star_rounded : Icons.star_outline_rounded, size: 32, color: ac.gold),
                  onPressed: () => setM(() => selected = i + 1),
                ),
            )),
            const SizedBox(height: 12),
            PrimaryBtn(label: 'Submit Rating', onTap: () {
              HapticFeedback.mediumImpact();
              PublicCourseRepository.instance.rate(course.id, currentUser!.id, selected);
              Navigator.pop(dCtx);
            }),
          ]),
        );
      }),
    );
  }
}

class _PrerequisitesLinks extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _PrerequisitesLinks({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return FutureBuilder<List<PublicCourse>>(
      future: Future.wait(course.prerequisiteIds.map(
          (id) => PublicCourseRepository.instance.watchOne(id).first)).then(
              (list) => list.whereType<PublicCourse>().toList()),
      builder: (context, snap) {
        final prereqs = snap.data ?? const <PublicCourse>[];
        if (prereqs.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Read first', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: ac.primary)),
            const SizedBox(height: 4),
            ...prereqs.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${p.title}', style: AppText.caption.copyWith(fontSize: 12, color: ac.primary)),
            )),
          ]),
        );
      },
    );
  }
}

class _ActionRow extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  const _ActionRow({required this.course, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final u = currentUser;
    final repo = PublicCourseRepository.instance;
    return Row(children: [
      if (u == null)
        Text('Sign in to like or save this course.', style: AppText.bodySm.copyWith(color: ac.txt2))
      else ...[
        StreamBuilder<bool>(
          stream: repo.watchIsLiked(course.id, u.id),
          builder: (context, snap) {
            final liked = snap.data ?? false;
            return _ActionChip(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? ac.red : ac.txt2,
              label: '${course.likeCount}',
              onTap: () { HapticFeedback.selectionClick(); repo.toggleLike(course.id, u.id); },
            );
          },
        ),
        const SizedBox(width: 18),
        StreamBuilder<bool>(
          stream: repo.watchIsBookmarked(course.id, u.id),
          builder: (context, snap) {
            final saved = snap.data ?? false;
            return _ActionChip(
              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? ac.gold : ac.txt2,
              label: saved ? 'Saved' : 'Save',
              onTap: () { HapticFeedback.selectionClick(); repo.toggleBookmark(course.id, u.id); },
            );
          },
        ),
      ],
      const Spacer(),
      _ActionChip(
        icon: Icons.share_outlined, color: ac.txt2, label: 'Share',
        onTap: () {
          HapticFeedback.selectionClick();
          Share.share('${course.title}\n\nRead it on Academia.');
        },
      ),
    ]);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppText.bodySm.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _CommentsTab extends StatelessWidget {
  final PublicCourse course;
  final AppUser? currentUser;
  final TextEditingController commentCtrl;
  final bool posting;
  final VoidCallback onPost;
  const _CommentsTab({
    required this.course, required this.currentUser,
    required this.commentCtrl, required this.posting, required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (currentUser != null)
          Row(children: [
            Expanded(
              child: TextField(
                controller: commentCtrl,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  filled: true, fillColor: ac.surf3,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            posting
                ? const SizedBox(width: 40, height: 40,
                    child: Center(child: SizedBox(width: 18, height: 18, child: SkeletonSpinner(strokeWidth: 2))))
                : IconButton(icon: Icon(Icons.send_rounded, color: ac.primary), onPressed: onPost),
          ])
        else
          Text('Sign in to join the discussion.', style: AppText.bodySm.copyWith(color: ac.txt2)),
        const SizedBox(height: 16),
        StreamBuilder<List<CourseComment>>(
          stream: PublicCourseRepository.instance.watchComments(course.id),
          builder: (context, cSnap) {
            final comments = cSnap.data ?? const <CourseComment>[];
            if (comments.isEmpty) {
              return Text('No comments yet — start the discussion.', style: AppText.bodySm.copyWith(color: ac.txt2));
            }
            return Column(children: comments.map((cm) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                UserAvatar(initials: cm.authorName.isEmpty ? '?' : cm.authorName[0].toUpperCase(),
                    radius: 14, photoUrl: cm.authorPhotoUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cm.authorName, style: AppText.subtitle.copyWith(color: ac.txt)),
                    const SizedBox(height: 3),
                    Text(cm.body, style: AppText.bodySm.copyWith(height: 1.4)),
                  ]),
                ),
              ]),
            )).toList());
          },
        ),
      ],
    );
  }
}
