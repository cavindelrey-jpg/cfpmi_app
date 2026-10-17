// lib/features/dashboard/universal_home_page.dart
//
// Personalized Academic Command Center for students.
//
// Re-architected according to senior UX/UI principles:
// 1. Personalized Context & Greeting: Time-of-day greeting, student identity, and academic session.
// 2. Academic Command Center Hero: Prioritizes the immediate next action ("what should I do now?"):
//    resumes active reading, prompts pending daily streak challenges, surfaces upcoming classes/tasks,
//    or kicks off exploration for new students.
// 3. Goal-Gradient Momentum Strip: Real, unfabricated progress metrics (daily streak, weekly study goal,
//    lifetime XP, passed quizzes, and school GPA average) with deep-link navigation.
// 4. Structured Academic Hubs: Progressive disclosure replacing equal-weight clutter:
//    - 4 Primary Hubs (Library, Past Questions, Quizzes, Courses)
//    - Secondary Tools (Dictionary, Groups, Daily Challenge Hub, Magazine, School Connect)
// 5. Schedule & Tasks: Real school timetable/personal study slots paired with live homework assignments.
// 6. Campus & Community Pulse: Live institutional announcements and upcoming club events.
// 7. Personalized Recommendations: Weighted subject recommendations via rankHomeSubjectsByUsage.
// 8. Academic Profile Summary Footer: Endowing ownership with student identity and entitlements.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/academic_content.dart';
import '../../models/announcement.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../models/daily_learning.dart';
import '../../models/daily_learning_streak.dart';
import '../../models/homework.dart';
import '../../models/school_mark.dart';
import '../../models/school_timetable_slot.dart';
import '../../repositories/academic_content_repository.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/club_repository.dart';
import '../../repositories/daily_learning_repository.dart';
import '../../repositories/homework_repository.dart';
import '../../repositories/school_marks_repository.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../repositories/test_repository.dart';
import '../../repositories/xp_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/hero_banner_carousel.dart';
import '../../models/hero_slide.dart';
import '../../models/public_course.dart';
import '../../repositories/public_course_repository.dart';
import '../courses_marketplace/course_lessons_page.dart';
import '../academic_content/content_details_page.dart';
import '../academic_content/content_viewer_page.dart';
import '../academic_content/library_home_page.dart';
import '../clubs/clubs_page.dart';
import '../courses_marketplace/courses_home_page.dart';
import '../daily_learning/daily_learning_hub_page.dart';
import '../daily_learning/daily_learning_lesson_page.dart';
import '../school/daily_notices/daily_notices_page.dart';
import '../school/homework_page.dart';
import '../school/marks_page.dart';
import '../school/school_calendar_page.dart';
import '../school/student_records_page.dart';
import '../classroom/student_classroom_page.dart';
import '../school/timetable_page.dart';
import '../testing/quiz_categories_page.dart';
import '../testing/xp_dashboard_page.dart';

/// Card shadow used throughout this page — soft, physical elevation.
const List<BoxShadow> _glow = [
  BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 4)),
];

// ── Dashboard spec palette (navy-blue, gold, emerald) ───────────────────
const Color _cNavy = Color(0xFF0B1F3A); // deep academic navy
const Color _cDarkGreen = Color(0xFF004D40); // deep forest green
const Color _cGreen = Color(0xFF087F5B); // emerald green
const Color _cGold = Color(0xFFF4C542); // warm academic gold
const Color _cCard = Color(0xFFFFFFFF);
const Color _cText = Color(0xFF14213D);
const Color _cText2 = Color(0xFF64748B);
const Color _cBorder = Color(0xFFE5E7EB);
const Color _cInfo = Color(0xFF2563EB); // information blue
const Color _cPurple = Color(0xFF7C3AED);
const Color _cOrange = Color(0xFFEA580C);
// pale icon-chip backgrounds
const Color _cPaleGreen = Color(0xFFE8F7ED);
const Color _cPaleYellow = Color(0xFFFFF8E1);
const Color _cPaleBlue = Color(0xFFEFF6FF);
const Color _cPalePurple = Color(0xFFF3E8FF);

// ── Home's own "Recommended for You" ranking helpers ───────────────────
// Pure, top-level, unit-tested (test/home_recommendation_ranking_test.dart)
// — deliberately independent copies of the same shape of logic
// RecommendationRepository.rankSubjectsByUsage uses for contextual
// recommendations. Preserved exactly for test compatibility.

/// Reorders [favoriteSubjects] by descending completion count in [usage] --
/// the subject a student actually completes quizzes in most often outranks
/// one they only starred. Ties keep their ORIGINAL relative order via an
/// explicit index tie-break.
List<String> rankHomeSubjectsByUsage(
  List<String> favoriteSubjects,
  Map<String, int> usage,
) {
  final indexed = favoriteSubjects.asMap().entries.toList()
    ..sort((a, b) {
      final byUsage = (usage[b.value] ?? 0).compareTo(usage[a.value] ?? 0);
      if (byUsage != 0) return byUsage;
      return a.key.compareTo(b.key);
    });
  return indexed.map((e) => e.value).toList();
}

class UniversalHomePage extends StatefulWidget {
  final AppUser? user;

  /// When true, the page omits its own top bar because the application shell
  /// already provides a single unified top bar.
  final bool embedded;

  /// Optional callback to switch the active destination in HomeShell.
  final ValueChanged<String>? onSelectSection;

  const UniversalHomePage({
    super.key,
    this.user,
    this.embedded = false,
    this.onSelectSection,
  });

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  bool get _isGuest => widget.user == null;
  AppUser? get _u => widget.user;
  AppUser get _userOrGuest => _u ?? AppUser.guest();

  AppColors get ac => AppColors.of(context);



  // ── Cached Streams & Futures (Prevent infinite rebuild loops) ───────
  Stream<DailyLearningStreak?>? _streakStream;
  Stream<(int, int)>? _xpStream;
  Future<Map<String, int>>? _completionCountsFuture;
  Future<({DailyLearningCourse course, DailyLearningLesson lesson, int completedCount, int totalCount})?>? _pendingDailyLessonFuture;
  Future<({double average, List<SchoolMark> subjects})?>? _latestMarksFuture;
  Stream<List<SchoolTimetableSlot>>? _timetableStream;
  Stream<List<Homework>>? _homeworkStream;
  Stream<List<Announcement>>? _announcementsStream;
  Future<List<({String clubName, ClubEvent event})>>? _upcomingClubEventsFuture;

  void _initStreamsAndFutures() {
    final uid = _u?.id ?? '';
    final schoolId = _u?.schoolId;
    final classLevel = _u?.classLevel ?? '';

    if (_isGuest || uid.isEmpty) {
      _streakStream = const Stream.empty();
      _xpStream = const Stream.empty();
      _completionCountsFuture = Future.value(const {});
      _pendingDailyLessonFuture = Future.value(null);
      _latestMarksFuture = Future.value(null);
      _timetableStream = const Stream.empty();
      _homeworkStream = const Stream.empty();
      _announcementsStream = const Stream.empty();
      _upcomingClubEventsFuture = Future.value(const []);
      return;
    }

    _streakStream = DailyLearningRepository.instance.watchStreak(uid);
    _xpStream = XpRepository.instance.watchBalance(uid);
    _completionCountsFuture = TestRepository.instance.subjectCompletionCountsOnce(uid);
    _pendingDailyLessonFuture = _getPendingDailyLesson();

    if (_u!.isSchoolMember) {
      _latestMarksFuture = _latestMarksSummary();
    } else {
      _latestMarksFuture = Future.value(null);
    }

    if (_u!.isSchoolMember && schoolId != null && schoolId.isNotEmpty && classLevel.isNotEmpty) {
      _timetableStream = SchoolTimetableRepository.instance.watchTodayForClass(schoolId, classLevel);
      _homeworkStream = HomeworkRepository.instance.watchForClass(schoolId, classLevel);
    } else {
      _timetableStream = const Stream.empty();
      _homeworkStream = const Stream.empty();
    }

    _announcementsStream = AnnouncementRepository.instance.watchAnnouncements(schoolId: schoolId);
    _upcomingClubEventsFuture = _upcomingClubEvents();
  }

  Future<void> _handleRefresh() async {
    _continueReadingKey = null;
    _cachedContinueReadingFuture = null;
    _recommendedKey = null;
    _cachedRecommendedFuture = null;
    if (mounted) {
      setState(() {
        _initStreamsAndFutures();
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  void initState() {
    super.initState();
    _initStreamsAndFutures();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
    if (!_isGuest) {
      AuthService.instance.recordDailyActivity(_u!);
    }
  }

  @override
  void didUpdateWidget(UniversalHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.user?.schoolId != widget.user?.schoolId ||
        oldWidget.user?.classLevel != widget.user?.classLevel) {
      _continueReadingKey = null;
      _cachedContinueReadingFuture = null;
      _recommendedKey = null;
      _cachedRecommendedFuture = null;
      _initStreamsAndFutures();
    }
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // ── Continue Reading Data ──────────────────────────────────────────
  String? _continueReadingKey;
  Future<({AcademicContent content, int page, int totalPages})?>? _cachedContinueReadingFuture;
  Future<({AcademicContent content, int page, int totalPages})?> get _continueReadingFuture {
    final key = _u?.id ?? '';
    if (_cachedContinueReadingFuture == null || _continueReadingKey != key) {
      _continueReadingKey = key;
      _cachedContinueReadingFuture = _isGuest
          ? Future.value(null)
          : AcademicContentRepository.instance.continueReading(_u!.id);
    }
    return _cachedContinueReadingFuture!;
  }

  Future<void> _reopenContinueReading(
      BuildContext context, ({AcademicContent content, int page, int totalPages}) data) async {
    final localPath = await AcademicContentRepository.instance.offlineFilePath(data.content.id);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ContentViewerPage(
              fileUrl: data.content.fileUrl ?? '',
              localFilePath: localPath,
              title: data.content.title,
              kind: ViewableFileKind.pdf,
              contentId: data.content.id,
              userId: _u!.id,
            )));
  }

  // ── Pending Daily Lesson Discovery ─────────────────────────────────
  Future<({DailyLearningCourse course, DailyLearningLesson lesson, int completedCount, int totalCount})?>
      _getPendingDailyLesson() async {
    if (_isGuest) return null;
    try {
      final courses = DailyLearningRepository.instance.courses;
      if (courses.isEmpty) return null;
      for (final course in courses) {
        final progressRecord = await DailyLearningRepository.instance
            .watchProgress(_u!.id, course.id)
            .first
            .timeout(const Duration(seconds: 3), onTimeout: () => (const <String>{}, null));
        final completed = progressRecord.$1;
        for (final l in course.lessons) {
          if (!completed.contains(l.id)) {
            return (
              course: course,
              lesson: l,
              completedCount: completed.length,
              totalCount: course.lessons.length,
            );
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Weekly Activity Count ──────────────────────────────────────────
  int _weekActivityCount() {
    if (_isGuest) return 0;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final activity = _u!.weekActivityDates.toSet();
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (activity.contains(key)) count++;
    }
    return count;
  }

  // ── Marks Summary ──────────────────────────────────────────────────
  Future<({double average, List<SchoolMark> subjects})?> _latestMarksSummary() async {
    if (_isGuest || !_u!.isSchoolMember) return null;
    try {
      final all = await SchoolMarksRepository.instance.allMarksOnce(_u!.id);
      if (all.isEmpty) return null;
      AcademicSequence? latest;
      for (final m in all) {
        if (latest == null || AcademicSequence.values.indexOf(m.sequence) > AcademicSequence.values.indexOf(latest)) {
          latest = m.sequence;
        }
      }
      final subjects = all.where((m) => m.sequence == latest).toList()
        ..sort((a, b) => a.subject.compareTo(b.subject));
      return (average: averagePercentage(subjects), subjects: subjects);
    } catch (_) {
      return null;
    }
  }

  // ── Club Events ───────────────────────────────────────────────────
  Future<List<({String clubName, ClubEvent event})>> _upcomingClubEvents() async {
    if (_isGuest) return const [];
    try {
      final clubIds = await ClubRepository.instance
          .watchMyClubIds(_u!.id)
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => const <String>[]);
      if (clubIds.isEmpty) return const [];
      final clubs = await ClubRepository.instance
          .watchMyClubs(_u!.id, user: _u)
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => const <Club>[]);
      final nameById = {for (final c in clubs) c.id: c.name};
      final out = <({String clubName, ClubEvent event})>[];
      for (final id in clubIds.take(3)) {
        if (!nameById.containsKey(id)) continue;
        final events = await ClubRepository.instance
            .watchEvents(id)
            .first
            .timeout(const Duration(seconds: 4), onTimeout: () => const <ClubEvent>[]);
        for (final e in events) {
          if (e.startAt.isAfter(DateTime.now())) out.add((clubName: nameById[id] ?? '', event: e));
        }
      }
      out.sort((a, b) => a.event.startAt.compareTo(b.event.startAt));
      return out.take(2).toList();
    } catch (_) {
      return const [];
    }
  }

  String _eventTimeLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${days[d.weekday - 1]}, ${h.toString()}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  // ── Recommendations ───────────────────────────────────────────────
  String? _recommendedKey;
  Future<List<Object>>? _cachedRecommendedFuture;
  Future<List<Object>> get _recommendedFuture {
    final key = '${_u?.id}:${_u?.schoolId}:$_isGuest';
    if (_cachedRecommendedFuture == null || _recommendedKey != key) {
      _recommendedKey = key;
      _cachedRecommendedFuture = _loadRecommended();
    }
    return _cachedRecommendedFuture!;
  }

  Future<List<Object>> _loadRecommended() async {
    final contentRepo = AcademicContentRepository.instance;
    final schoolId = _u?.schoolId;
    final favSubjects = _u?.favoriteSubjects ?? const <String>[];

    var libraryItems = <AcademicContent>[];
    if (!_isGuest && favSubjects.isNotEmpty) {
      var usage = const <String, int>{};
      try {
        usage = await TestRepository.instance.subjectCompletionCountsOnce(_u!.id);
      } catch (_) {
        // Fallback to unweighted order
      }
      final ranked = rankHomeSubjectsByUsage(favSubjects, usage);
      final perSubject = await Future.wait(ranked.map((s) => contentRepo
          .watch(institutionId: schoolId, subject: s)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const <AcademicContent>[])));
      final seenIds = <String>{};
      var round = 0;
      while (libraryItems.length < 4 && perSubject.any((l) => round < l.length)) {
        for (final list in perSubject) {
          if (round >= list.length) continue;
          final item = list[round];
          if (seenIds.add(item.id)) libraryItems.add(item);
          if (libraryItems.length >= 4) break;
        }
        round++;
      }
    }
    if (libraryItems.isEmpty) {
      final fallback = await contentRepo
          .watch(institutionId: schoolId)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const <AcademicContent>[]);
      libraryItems = fallback.take(4).toList();
    }

    return libraryItems;
  }

  // ── Build Method ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: ac.bg,
      child: SafeArea(
        child: RefreshIndicator(
          color: ac.primary,
          backgroundColor: ac.surf,
          onRefresh: _handleRefresh,
          // Branch on the ACTUAL available width (not the window) so the
          // two-column desktop dashboard only kicks in when there's room —
          // the mobile single column stays single on phones.
          child: LayoutBuilder(
            builder: (context, c) =>
                c.maxWidth >= 760 ? _desktopBody(context) : _mobileBody(context),
          ),
        ),
      ),
    );
  }

  void _navigateToSectionOrOpen(BuildContext context, String section, Widget fallbackPage) {
    if (widget.onSelectSection != null) {
      widget.onSelectSection!(section);
    } else {
      _open(context, fallbackPage);
    }
  }

  // Mobile: single vertical column beginning immediately below the top bar,
  // with no repeated page heading or subtitle.
  Widget _mobileBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 36),
      children: [
        _featuredBanner(context),
        const SizedBox(height: 18),
        _commandCenterHero(context),
        const SizedBox(height: 22),
        _sh('Quick Access',
            onTap: () => _navigateToSectionOrOpen(context, 'Library', LibraryHomePage(user: _userOrGuest))),
        const SizedBox(height: 12),
        _quickAccessSection(context),
        const SizedBox(height: 22),
        _studentProgressCard(context),
        const SizedBox(height: 24),
        _sh('Featured Courses',
            action: 'Browse All',
            onTap: () => _navigateToSectionOrOpen(context, 'Courses', CoursesHomePage(user: _u))),
        const SizedBox(height: 12),
        _featuredCoursesSection(context),
        const SizedBox(height: 24),
        _scheduleAnnouncementsSection(context),
        const SizedBox(height: 16),
        _tasksAndCalendarSection(context),
        const SizedBox(height: 16),
        _recommendedReadsSection(context),
      ],
    );
  }

  // Desktop/web: balanced two-column dashboard beginning immediately below the top bar,
  // with rich content on the left and personal productivity on the right.
  Widget _desktopBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _featuredBanner(context),
                    const SizedBox(height: 18),
                    _commandCenterHero(context),
                    const SizedBox(height: 22),
                    _sh('Quick Access',
                        onTap: () => _navigateToSectionOrOpen(context, 'Library', LibraryHomePage(user: _userOrGuest))),
                    const SizedBox(height: 12),
                    _quickAccessSection(context),
                    const SizedBox(height: 24),
                    _sh('Featured Courses',
                        action: 'Browse All',
                        onTap: () => _navigateToSectionOrOpen(context, 'Courses', CoursesHomePage(user: _u))),
                    const SizedBox(height: 12),
                    _featuredCoursesSection(context),
                    const SizedBox(height: 20),
                    _recommendedReadsSection(context),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _studentProgressCard(context),
                    const SizedBox(height: 18),
                    _scheduleAnnouncementsSection(context),
                    const SizedBox(height: 18),
                    _tasksAndCalendarSection(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tasks & Homework + Calendar & Events row
  Widget _tasksAndCalendarSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final tasksCard = _panelCard(
            title: 'Tasks & Homework',
            actionLabel: 'View all',
            onAction: () => _navigateToSectionOrOpen(
              context,
              'Homework',
              HomeworkPage(user: _userOrGuest),
            ),
            child: _tasksCardContent(context),
          );
          final calendarCard = _panelCard(
            title: 'Academic Calendar',
            actionLabel: 'Open calendar',
            onAction: () => _open(context, SchoolCalendarPage(user: _userOrGuest)),
            child: _myClubContent(context),
          );
          if (c.maxWidth < 340) {
            return Column(
              children: [
                tasksCard,
                const SizedBox(height: 12),
                calendarCard,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tasksCard),
                const SizedBox(width: 12),
                Expanded(child: calendarCard),
              ],
            ),
          );
        },
      ),
    );
  }

  // Right-rail "Recommended for You" — real Library/Article content.
  Widget _recommendedReadsSection(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _recommendedFuture,
      builder: (context, snap) {
        final items =
            (snap.data ?? const <Object>[]).whereType<AcademicContent>().take(4).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cBorder),
              boxShadow: _glow,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: _cGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Recommended Articles & Reads',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w800, color: _cNavy)),
                ),
              ]),
              const SizedBox(height: 4),
              for (final it in items)
                InkWell(
                  onTap: () => _open(
                      context, ContentDetailsPage(contentId: it.id, user: _userOrGuest)),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: _cPaleGreen, borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.description_rounded, size: 17, color: _cGreen),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 12.5, fontWeight: FontWeight.w700, color: _cText)),
                          if (it.subject.isNotEmpty)
                            Text(it.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 11, color: _cText2)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: _cText2),
                    ]),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }


  // ── Section header: bold navy title + green "View all →" action ─────
  Widget _sh(String title, {String action = 'View all', VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800, color: _cNavy),
            ),
          ),
          if (onTap != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(action,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: _cGreen)),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: _cGreen),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Featured promotional banner ─────────────────────────────────────
  Widget _featuredBanner(BuildContext context) {
    // Admin-editable, swipeable banner carousel: real content, auto-rotating,
    // with arrows + swipe + pagination indicators. Replaces the single static
    // banner. Changing/updating slides rebuilds only this widget, not the page.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HeroBannerCarousel(
        placement: HeroPlacement.home,
        user: _u,
      ),
    );
  }

  // ── Quick Access (4 feature cards, horizontally scrollable) ─────────
  // A responsive card row: a wrapping grid on desktop/web (uses the width),
  // a horizontal scroller on phones — not both directions on one screen.
  Widget _cardRow(List<Widget> cards) {
    return LayoutBuilder(
      builder: (ctx, c) {
        if (c.maxWidth >= 600) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 10, runSpacing: 10, children: cards),
          );
        }
        final children = <Widget>[];
        for (var i = 0; i < cards.length; i++) {
          if (i > 0) children.add(const SizedBox(width: 10));
          children.add(cards[i]);
        }
        return SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: children,
          ),
        );
      },
    );
  }

  Widget _quickAccessSection(BuildContext context) => _cardRow([
        _featureCard(
            icon: Icons.menu_book_rounded, iconColor: _cGreen, iconBg: _cPaleGreen,
            title: 'My Courses', subtitle: 'Access your lessons',
            onTap: () => _open(context, CoursesHomePage(user: _u))),
        _featureCard(
            icon: Icons.assignment_turned_in_rounded, iconColor: const Color(0xFFB7791F), iconBg: _cPaleYellow,
            title: 'My Marks', subtitle: 'View your results',
            onTap: () => _open(context, MarksPage(user: _userOrGuest))),
        _featureCard(
            icon: Icons.description_rounded, iconColor: _cInfo, iconBg: _cPaleBlue,
            title: 'Past Papers', subtitle: 'GCE, A-level & exams',
            onTap: () => _open(context, LibraryHomePage(user: _userOrGuest))),
        _featureCard(
            icon: Icons.school_rounded, iconColor: _cPurple, iconBg: _cPalePurple,
            title: 'Campus Info', subtitle: 'Timetable & notices',
            onTap: () => _open(context, TimetablePage(user: _userOrGuest))),
        _featureCard(
            icon: Icons.badge_rounded, iconColor: _cGreen, iconBg: _cPaleGreen,
            title: 'My Records', subtitle: 'Attendance & fees',
            onTap: () => _open(context, StudentRecordsPage(user: _userOrGuest))),
        _featureCard(
            icon: Icons.sensors_rounded, iconColor: _cPurple, iconBg: _cPalePurple,
            title: 'Live Class', subtitle: 'Join the lesson',
            onTap: () => _open(context, StudentClassroomPage(user: _userOrGuest))),
      ]);

  Widget _featureCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 116,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cBorder),
          boxShadow: _glow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              // Nested radius rule: outer 16px - inset = 8px
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _cText)),
            const SizedBox(height: 3),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: _cText2, height: 1.25)),
          ],
        ),
      ),
    );
  }

  // ── Student progress card (dark green, 4 columns) ───────────────────
  Widget _studentProgressCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<DailyLearningStreak?>(
        stream: _streakStream ?? const Stream.empty(),
        builder: (context, streakSnap) {
          final streakCount = streakSnap.data?.currentStreak ?? 0;
          return StreamBuilder<(int, int)>(
            stream: _xpStream ?? const Stream.empty(),
            builder: (context, xpSnap) {
              final xp = _isGuest ? 0 : (xpSnap.data?.$2 ?? 0);
              return FutureBuilder<Map<String, int>>(
                future: _completionCountsFuture ?? Future.value(const {}),
                builder: (context, qSnap) {
                  final quizzes =
                      (qSnap.data ?? const {}).values.fold<int>(0, (s, v) => s + v);
                  final activeDays = _weekActivityCount();
                  final pct = (activeDays / 7 * 100).round().clamp(0, 100);
                  return GestureDetector(
                    onTap: () => _open(context, XpDashboardPage(user: _userOrGuest)),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_cDarkGreen, Color(0xFF066352)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _glow,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.insights_rounded, color: _cGold, size: 16),
                                  const SizedBox(width: 6),
                                  Text('YOUR PROGRESS',
                                      style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: _cGold,
                                          letterSpacing: 0.8)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('View Details',
                                      style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.9))),
                                  const SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 13, color: Colors.white.withValues(alpha: 0.9)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _open(context, XpDashboardPage(user: _userOrGuest)),
                                    child: _progressRing(pct),
                                  ),
                                ),
                                _progressSep(),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _open(context, XpDashboardPage(user: _userOrGuest)),
                                    child: _progressStat(
                                        Icons.star_rounded, _cGold, '$xp', 'XP Points'),
                                  ),
                                ),
                                _progressSep(),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _open(context, DailyLearningHubPage(user: _userOrGuest)),
                                    child: _progressStat(Icons.local_fire_department_rounded,
                                        _cOrange, '$streakCount', 'Day Streak'),
                                  ),
                                ),
                                _progressSep(),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _open(context, QuizCategoriesPage(user: _userOrGuest)),
                                    child: _progressStat(Icons.emoji_events_rounded, _cGold,
                                        '$quizzes', 'Quizzes Done'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isGuest && _u!.isSchoolMember) ...[
                            const SizedBox(height: 14),
                            Divider(height: 1, color: Colors.white.withValues(alpha: 0.16)),
                            const SizedBox(height: 10),
                            FutureBuilder<({double average, List<SchoolMark> subjects})?>(
                              future: _latestMarksFuture,
                              builder: (context, marksSnap) {
                                final marksData = marksSnap.data;
                                if (marksData == null || marksData.subjects.isEmpty) {
                                  return InkWell(
                                    onTap: () => _open(context, MarksPage(user: _userOrGuest)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.assessment_outlined, color: Colors.white.withValues(alpha: 0.8), size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'View official school marks & grade reports',
                                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                                          ),
                                        ),
                                        Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                      ],
                                    ),
                                  );
                                }
                                return InkWell(
                                  onTap: () => _open(context, MarksPage(user: _userOrGuest)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${marksData.average.round()}%',
                                            style: GoogleFonts.sora(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: _cGold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Term Average: ${marksData.average.toStringAsFixed(1)}% · ${marksData.subjects.length} subject${marksData.subjects.length == 1 ? '' : 's'} recorded',
                                          style: GoogleFonts.sora(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _progressSep() => Container(width: 1, color: Colors.white.withValues(alpha: 0.14));

  Widget _progressRing(int pct) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(_cGold),
                ),
              ),
              Text('$pct%',
                  style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Weekly Goal',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 10.5, color: Colors.white.withValues(alpha: 0.85))),
      ],
    );
  }

  Widget _progressStat(IconData icon, Color iconColor, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 10.5, color: Colors.white.withValues(alpha: 0.85))),
      ],
    );
  }

  // ── Featured courses (horizontal carousel) ──────────────────────────
  Future<List<PublicCourse>>? _featuredCoursesFuture;
  Future<List<PublicCourse>> get _featuredCourses =>
      _featuredCoursesFuture ??= PublicCourseRepository.instance.watchFeaturedOnce(count: 8);

  Widget _featuredCoursesSection(BuildContext context) {
    return SizedBox(
      height: 222,
      child: FutureBuilder<List<PublicCourse>>(
        future: _featuredCourses,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 13),
              itemBuilder: (_, __) => const SizedBox(
                width: 196,
                child: ShimmerCard(height: 210),
              ),
            );
          }
          final courses = snap.data ?? const <PublicCourse>[];
          if (courses.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Text('No featured courses yet.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: _cText2)),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 13),
            itemBuilder: (context, i) => _courseCard(context, courses[i]),
          );
        },
      ),
    );
  }

  // A real featured course card: admin thumbnail (coverImageUrl) when present,
  // tapping opens THAT course (CourseLessonsPage), not a generic list.
  Widget _courseCard(BuildContext context, PublicCourse course) {
    final subject = course.subject.isNotEmpty
        ? course.subject
        : (course.category.isNotEmpty ? course.category : 'Course');
    final cover = course.coverImageUrl;
    return GestureDetector(
      onTap: () => _open(context, CourseLessonsPage(course: course, currentUser: _u)),
      child: Container(
        width: 196,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cBorder),
          boxShadow: _glow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: (cover != null && cover.isNotEmpty)
                    ? Image.network(cover, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => courseCoverFallback(course.title))
                    : courseCoverFallback(course.title),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 42, child: Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: _cText, height: 1.15))),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Icon(Icons.people_alt_rounded, size: 14, color: _cText2),
                    const SizedBox(width: 5),
                    Text('${course.enrolledCount} learners',
                        style: GoogleFonts.inter(fontSize: 12, color: _cText2)),
                  ]),
                  Container(width: 30, height: 30,
                    decoration: const BoxDecoration(color: _cPaleYellow, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, size: 16, color: _cNavy)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's Schedule + Announcements (two cards) ────────────────────
  Widget _scheduleAnnouncementsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final schedule = _scheduleCard(context);
          final announce = _announcementsCard(context);
          if (c.maxWidth < 340) {
            return Column(children: [schedule, const SizedBox(height: 12), announce]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: schedule),
                const SizedBox(width: 12),
                Expanded(child: announce),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scheduleCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context, TimetablePage(user: _userOrGuest)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cPaleGreen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cGreen.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 15, color: _cDarkGreen),
              const SizedBox(width: 6),
              Expanded(child: Text("Today's Schedule", maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _cDarkGreen))),
            ]),
            const SizedBox(height: 12),
            StreamBuilder<List<SchoolTimetableSlot>>(
              stream: _timetableStream ?? const Stream.empty(),
              builder: (context, snap) {
                final slots = [...(snap.data ?? const <SchoolTimetableSlot>[])]
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));
                if (slots.isEmpty) {
                  return Text('No classes scheduled today.',
                      style: GoogleFonts.inter(fontSize: 12, color: _cText2));
                }
                final sl = slots.first;
                final where = (sl.room ?? '').isNotEmpty ? sl.room! : sl.teacherName;
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sl.startTime, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _cText)),
                    const SizedBox(height: 4),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: _cGreen, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sl.subject.isEmpty ? 'Class' : sl.subject, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _cText)),
                    if (where.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(where, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: _cText2)),
                    ],
                  ])),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _announcementsCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context, DailyNoticesPage(user: _userOrGuest)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cPaleYellow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cGold.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.campaign_rounded, size: 16, color: Color(0xFFB7791F)),
              const SizedBox(width: 6),
              Expanded(child: Text('Announcements', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF8A6D1B)))),
            ]),
            const SizedBox(height: 12),
            StreamBuilder<List<Announcement>>(
              stream: _announcementsStream ?? const Stream.empty(),
              builder: (context, snap) {
                final items = snap.data ?? const <Announcement>[];
                if (items.isEmpty) {
                  return Text('No announcements yet.',
                      style: GoogleFonts.inter(fontSize: 12, color: _cText2));
                }
                final a = items.first;
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(margin: const EdgeInsets.only(top: 5), width: 8, height: 8,
                      decoration: const BoxDecoration(color: _cGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _cText)),
                    if (a.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: _cText2)),
                    ],
                  ])),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: _cText2),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Academic Command Center Hero ("What should I do now?") ─────────
  Widget _commandCenterHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<({AcademicContent content, int page, int totalPages})?>(
        future: _continueReadingFuture,
        builder: (context, readSnap) {
          final readingData = readSnap.data;

          return StreamBuilder<DailyLearningStreak?>(
            stream: _streakStream ?? const Stream.empty(),
            builder: (context, streakSnap) {
              final streak = streakSnap.data;
              final now = DateTime.now();
              final streakDoneToday = streak?.lastCompletedDate != null &&
                  streak!.lastCompletedDate!.year == now.year &&
                  streak.lastCompletedDate!.month == now.month &&
                  streak.lastCompletedDate!.day == now.day;

              return FutureBuilder<
                  ({
                    DailyLearningCourse course,
                    DailyLearningLesson lesson,
                    int completedCount,
                    int totalCount
                  })?>(
                future: _pendingDailyLessonFuture,
                builder: (context, pendingSnap) {
                  final pending = pendingSnap.data;

                  // 1. Priority: Continue Reading if available
                  if (readingData != null) {
                    final pct = readingData.totalPages > 0
                        ? (readingData.page / readingData.totalPages).clamp(0.0, 1.0)
                        : 0.0;
                    return _heroCardLayout(
                      context,
                      eyebrow: 'CONTINUE READING',
                      eyebrowIcon: Icons.menu_book_rounded,
                      eyebrowColor: ac.gold,
                      title: readingData.content.title,
                      subtitle:
                          '${readingData.content.subject.isNotEmpty ? '${readingData.content.subject} · ' : ''}Page ${readingData.page} of ${readingData.totalPages}',
                      progressPct: pct,
                      progressLabel: '${(pct * 100).round()}% complete',
                      primaryLabel: 'Resume Reading',
                      primaryIcon: Icons.arrow_forward_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _reopenContinueReading(context, readingData);
                      },
                      secondaryLabel: 'Browse Library',
                      onSecondary: () => _open(context, LibraryHomePage(user: _userOrGuest)),
                    );
                  }

                  // 2. Priority: Daily Challenge pending
                  if (pending != null && !streakDoneToday) {
                    final streakCount = streak?.currentStreak ?? 0;
                    final progressPct = pending.totalCount > 0
                        ? (pending.completedCount / pending.totalCount).clamp(0.0, 1.0)
                        : 0.0;

                    return _heroCardLayout(
                      context,
                      eyebrow: streakCount > 0 ? 'DAILY CHALLENGE · DAY ${streakCount + 1}' : 'DAILY CHALLENGE',
                      eyebrowIcon: Icons.local_fire_department_rounded,
                      eyebrowColor: ac.org,
                      title: '${pending.course.title}: ${pending.lesson.title}',
                      subtitle:
                          '${pending.lesson.questions.length} quick questions · Keep your streak alive & earn XP',
                      progressPct: progressPct,
                      progressLabel:
                          'Lesson ${pending.completedCount + 1} of ${pending.totalCount} in course',
                      primaryLabel: 'Start Challenge',
                      primaryIcon: Icons.play_arrow_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _open(
                          context,
                          DailyLearningLessonPage(
                            user: _userOrGuest,
                            course: pending.course,
                            lesson: pending.lesson,
                          ),
                        );
                      },
                      secondaryLabel: 'View All Courses',
                      onSecondary: () => _open(context, CoursesHomePage(user: _u)),
                    );
                  }

                  // 3. Priority: Daily Challenge completed today
                  if (streakDoneToday) {
                    final streakCount = streak.currentStreak;
                    return _heroCardLayout(
                      context,
                      eyebrow: 'DAILY GOAL ACHIEVED',
                      eyebrowIcon: Icons.verified_rounded,
                      eyebrowColor: ac.grn,
                      title: 'Great discipline today! 🔥',
                      subtitle:
                          'You\'ve secured your $streakCount-day learning streak. Explore past papers or take an Academia Quiz to earn more XP.',
                      primaryLabel: 'Explore Library',
                      primaryIcon: Icons.menu_book_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _open(context, LibraryHomePage(user: _userOrGuest));
                      },
                      secondaryLabel: 'Practice Quizzes',
                      onSecondary: () => _open(context, QuizCategoriesPage(user: _userOrGuest)),
                    );
                  }

                  // 4a. Staff: their working tools, not "start your
                  // learning journey" (which read as student copy).
                  final staff = _u;
                  if (staff != null && !staff.isStudent && staff.canRecordAnyMarks) {
                    return _heroCardLayout(
                      context,
                      eyebrow: 'YOUR CLASSES',
                      eyebrowIcon: Icons.co_present_rounded,
                      eyebrowColor: ac.gold,
                      title: 'Ready for today\'s lessons',
                      subtitle: 'Enter marks for a whole class, check your teaching timetable, or message your students.',
                      primaryLabel: 'Enter Marks',
                      primaryIcon: Icons.edit_note_rounded,
                      onPrimary: () {
                        HapticFeedback.selectionClick();
                        _open(context, MarksPage(user: staff));
                      },
                      secondaryLabel: 'My Timetable',
                      onSecondary: () => _open(context, TimetablePage(user: staff)),
                    );
                  }

                  // 4. Default for new accounts or guests
                  return _heroCardLayout(
                    context,
                    eyebrow: 'ACADEMIC COMMAND CENTER',
                    eyebrowIcon: Icons.explore_rounded,
                    eyebrowColor: ac.gold,
                    title: 'Start Your Learning Journey',
                    subtitle:
                        'Access official textbooks, solved past questions, subject drills, and intellectual masterclasses.',
                    primaryLabel: 'Explore Library',
                    primaryIcon: Icons.search_rounded,
                    onPrimary: () {
                      HapticFeedback.selectionClick();
                      _open(context, LibraryHomePage(user: _userOrGuest));
                    },
                    secondaryLabel: 'Start Daily Challenge',
                    onSecondary: () => _open(context, DailyLearningHubPage(user: _userOrGuest)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _heroCardLayout(
    BuildContext context, {
    required String eyebrow,
    required IconData eyebrowIcon,
    required Color eyebrowColor,
    required String title,
    required String subtitle,
    double? progressPct,
    String? progressLabel,
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.lg),
        gradient: LinearGradient(
          colors: [
            ac.navy,
            const Color(0xFF0F3A30),
            ac.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: _glow,
      ),
      child: Stack(
        children: [
          // Subtle background decorative radial accent
          Positioned(
            right: -40,
            bottom: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ac.gold.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eyebrow tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(Rad.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(eyebrowIcon, color: eyebrowColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            eyebrow,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.35,
                  ),
                ),
                if (progressPct != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPct,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(ac.gold),
                          ),
                        ),
                      ),
                      if (progressLabel != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          progressLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Rad.xs),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Rad.xs),
                        onTap: onPrimary,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(primaryIcon, size: 16, color: ac.navy),
                              const SizedBox(width: 6),
                              Text(
                                primaryLabel,
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ac.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Rad.xs),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onSecondary();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Text(
                              secondaryLabel,
                              style: GoogleFonts.sora(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _tasksCardContent(BuildContext context) {
    if (_isGuest) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _open(context, DailyLearningHubPage(user: _userOrGuest));
        },
        borderRadius: BorderRadius.circular(Rad.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ac.goldBg,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: ac.gold.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: ac.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Practice (+50 XP)',
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.gold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Practice quizzes & tests today',
                      style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ac.gold, size: 16),
            ],
          ),
        ),
      );
    }

    final schoolId = _u!.schoolId;
    if (_u!.isSchoolMember && schoolId != null && schoolId.isNotEmpty && _u!.classLevel.isNotEmpty) {
      return StreamBuilder<List<Homework>>(
        stream: _homeworkStream ?? const Stream.empty(),
        builder: (context, snap) {
          final homeworkList = snap.data ?? const <Homework>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }

          if (homeworkList.isNotEmpty) {
            final shown = homeworkList.take(2).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final h in shown) ...[
                  InkWell(
                    onTap: () => _open(context, HomeworkPage(user: _u!)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(color: ac.org, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                    fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt),
                              ),
                              Text(
                                '${h.subject} · Due ${_formatDueDate(h.dueAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (homeworkList.length > 2)
                  Text(
                    '+${homeworkList.length - 2} more assignment${homeworkList.length - 2 == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ac.primary),
                  ),
              ],
            );
          }

          return _readingTaskFallback(context);
        },
      );
    }

    return _readingTaskFallback(context);
  }

  Widget _readingTaskFallback(BuildContext context) {
    return FutureBuilder<({AcademicContent content, int page, int totalPages})?>(
      future: _continueReadingFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final data = snap.data;
        if (data == null) {
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(context, DailyLearningHubPage(user: _userOrGuest));
            },
            borderRadius: BorderRadius.circular(Rad.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ac.goldBg,
                borderRadius: BorderRadius.circular(Rad.sm),
                border: Border.all(color: ac.gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: ac.grn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Homework Clear! (+50 XP)',
                          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Take today\'s daily challenge',
                          style: GoogleFonts.inter(fontSize: 9.5, color: ac.gold, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ac.gold, size: 16),
                ],
              ),
            ),
          );
        }
        final pct = data.totalPages > 0 ? (data.page / data.totalPages).clamp(0.0, 1.0) : 0.0;
        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _reopenContinueReading(context, data);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(color: ac.primary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.txt),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reading task · ${(pct * 100).round()}% finished',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: ac.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDueDate(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays > 1 && diff.inDays < 7) return 'in ${diff.inDays} days';
    return '${due.day}/${due.month}';
  }

  Widget _panelCard({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr.withValues(alpha: 0.6)),
        boxShadow: _glow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.txt),
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAction();
                },
                child: Text(
                  actionLabel,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _myClubContent(BuildContext context) {
    if (_isGuest) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _open(context, ClubsPage(user: _userOrGuest));
        },
        borderRadius: BorderRadius.circular(Rad.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ac.grnBg,
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: ac.grn.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_outlined, color: ac.grn, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Circles',
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.grn),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore collaborative groups',
                      style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ac.grn, size: 16),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<List<({String clubName, ClubEvent event})>>(
      future: _upcomingClubEventsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(context, ClubsPage(user: _userOrGuest));
            },
            borderRadius: BorderRadius.circular(Rad.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ac.grnBg,
                borderRadius: BorderRadius.circular(Rad.sm),
                border: Border.all(color: ac.grn.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.group_add_outlined, color: ac.grn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Study Circles',
                          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: ac.grn),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Connect with peer revision groups',
                          style: GoogleFonts.inter(fontSize: 9.5, color: ac.txt2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ac.grn, size: 16),
                ],
              ),
            ),
          );
        }
        final first = items.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              first.clubName.isNotEmpty ? '${first.clubName}: ${first.event.title}' : first.event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.txt, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              _eventTimeLabel(first.event.startAt),
              style: GoogleFonts.inter(fontSize: 9.5, color: ac.muted),
            ),
          ],
        );
      },
    );
  }

}
