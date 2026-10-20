// lib/features/school/classroom_page.dart
// Virtual classroom hub inside ApplicationShell:
// - Real Class Banner + Class Group Chat launcher.
// - Live Classroom Session monitor (ClassroomRepository) for students & teachers.
// - Real class subjects & schedule derived from SchoolTimetableRepository
//   (no fabricated teacher names or fake room assignments).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/school_timetable_slot.dart';
import '../../repositories/classroom_repository.dart';
import '../../repositories/school_timetable_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/application_shell.dart';
import '../classroom/classroom_teacher_page.dart';
import '../classroom/student_classroom_page.dart';
import 'class_group_launcher.dart';
import 'timetable_page.dart';

class ClassroomPage extends StatelessWidget {
  final AppUser user;
  const ClassroomPage({super.key, required this.user});

  bool get _canTeach =>
      user.canRecordAnyMarks ||
      (user.isSchoolMember && !user.isStudent && !user.isParent);

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = user.effectiveSchoolId;

    return ApplicationShell(
      user: user,
      currentDestination: AppNavDestination.classroom,
      currentTitle: 'Classroom',
      subtitle: 'Live classroom sessions, class group discussion, and subject schedule',
      headerActions: [
        if (_canTeach)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClassroomTeacherPage(user: user),
                ),
              );
            },
            icon: const Icon(Icons.cast_for_education_rounded, size: 16),
            label: const Text('Teacher Console'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF081630),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          )
        else if (!user.isGuest && schoolId.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentClassroomPage(user: user),
                ),
              );
            },
            icon: const Icon(Icons.sensors_rounded, size: 16),
            label: const Text('Live Class View'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _classBanner(context, ac),
          const SizedBox(height: 20),
          _liveSessionCard(context, ac, schoolId),
          const SizedBox(height: 24),
          _subjectsSection(context, ac, schoolId),
        ],
      ),
    );
  }

  Widget _classBanner(BuildContext context, AppColors ac) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: ac.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.school_rounded, color: ac.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.classLevel.isNotEmpty
                        ? user.classLevel
                        : (_canTeach ? 'Staff Classroom Portal' : 'My Classroom'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ac.txt,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.schoolName.isNotEmpty
                        ? user.schoolName
                        : 'Connect to your school in Profile to access live sessions',
                    style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canOpenClassGroup(user))
                ElevatedButton.icon(
                  onPressed: () => openClassGroup(context, user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Rad.sm),
                    ),
                  ),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: const Text('Open Class Chat'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveSessionCard(
    BuildContext context,
    AppColors ac,
    String schoolId,
  ) {
    if (_canTeach) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF081630), Color(0xFF142B58)],
              ),
              borderRadius: BorderRadius.circular(Rad.md),
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5A93C).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.cast_for_education_rounded,
                              color: Color(0xFFE5A93C),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Interactive Classroom Presenter',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Start a live presentation, sync slides with student devices, and release lesson resources in real time.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFFC0D2F0),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ClassroomTeacherPage(user: user),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5A93C),
                            foregroundColor: const Color(0xFF081630),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.slideshow_rounded, size: 18),
                          label: const Text('Manage Sessions'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cast_for_education_rounded,
                          color: Color(0xFFE5A93C),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interactive Classroom Presenter',
                              style: GoogleFonts.inter(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start a live presentation, sync slides with student devices, and release lesson resources in real time.',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: const Color(0xFFC0D2F0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClassroomTeacherPage(user: user),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5A93C),
                          foregroundColor: const Color(0xFF081630),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.slideshow_rounded, size: 18),
                        label: const Text('Manage Sessions'),
                      ),
                    ],
                  ),
          );
        },
      );
    }

    if (schoolId.isEmpty || user.classLevel.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<ClassroomSession?>(
      stream: ClassroomRepository.instance
          .watchLiveForClass(schoolId, user.classLevel),
      builder: (context, snap) {
        final session = snap.data;
        final isLive = session != null && session.status == ClassroomStatus.live;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 620;
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isLive
                    ? const Color(0xFF081630)
                    : ac.surf,
                borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(
                  color: isLive ? const Color(0xFFE5A93C) : ac.bdr,
                ),
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isLive
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                    : ac.surf2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                                color: isLive ? const Color(0xFFEF4444) : ac.muted,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isLive
                                    ? 'LIVE NOW: ${session.subject} — ${session.topic}'
                                    : 'No live classroom presentation active',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isLive ? Colors.white : ac.txt,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isLive
                              ? 'Presented by ${session.teacherName} • Join to follow slides and take personal notes.'
                              : 'When a teacher starts a live session for ${user.classLevel}, you can follow the presentation and access released files here.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isLive ? const Color(0xFFC0D2F0) : ac.txt2,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StudentClassroomPage(user: user),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isLive ? const Color(0xFFE5A93C) : ac.primary,
                              foregroundColor:
                                  isLive ? const Color(0xFF081630) : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            icon: Icon(
                              isLive ? Icons.login_rounded : Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: Text(isLive ? 'Join Live Class' : 'Open Live Room'),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLive
                                ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                : ac.surf2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                            color: isLive ? const Color(0xFFEF4444) : ac.muted,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLive
                                    ? 'LIVE NOW: ${session.subject} — ${session.topic}'
                                    : 'No live classroom presentation active right now',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isLive ? Colors.white : ac.txt,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isLive
                                    ? 'Presented by ${session.teacherName} • Join to follow slides and take personal notes.'
                                    : 'When a teacher starts a live session for ${user.classLevel}, you can follow the presentation and access released files here.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: isLive ? const Color(0xFFC0D2F0) : ac.txt2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StudentClassroomPage(user: user),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isLive ? const Color(0xFFE5A93C) : ac.primary,
                            foregroundColor:
                                isLive ? const Color(0xFF081630) : Colors.white,
                          ),
                          icon: Icon(
                            isLive ? Icons.login_rounded : Icons.visibility_outlined,
                            size: 18,
                          ),
                          label: Text(isLive ? 'Join Live Class' : 'Open Live Room'),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _subjectsSection(
    BuildContext context,
    AppColors ac,
    String schoolId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Class Subjects & Schedule',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ac.txt,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TimetablePage(user: user)),
                );
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 15),
              label: const Text('Full Timetable'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (schoolId.isEmpty || user.classLevel.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr),
            ),
            child: Text(
              _canTeach
                  ? 'Use the Teacher Console above to start or manage classroom sessions for any class.'
                  : 'Link your school and class in Profile to see your class subjects and timetable.',
              style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
            ),
          )
        else
          StreamBuilder<List<SchoolTimetableSlot>>(
            stream: SchoolTimetableRepository.instance
                .watchForClass(schoolId, user.classLevel),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final slots = snap.data ?? const <SchoolTimetableSlot>[];
              if (slots.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ac.surf,
                    borderRadius: BorderRadius.circular(Rad.md),
                    border: Border.all(color: ac.bdr),
                  ),
                  child: Text(
                    'No class subjects have been scheduled for ${user.classLevel} yet.',
                    style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
                  ),
                );
              }

              // Group timetable slots by subject
              final bySubject = <String, List<SchoolTimetableSlot>>{};
              for (final s in slots) {
                if (s.subject.trim().isEmpty) continue;
                bySubject.putIfAbsent(s.subject.trim(), () => []).add(s);
              }
              final entries = bySubject.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));

              const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.3,
                ),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  final subjectSlots = entry.value;
                  final teacher = subjectSlots
                      .map((s) => s.teacherName ?? '')
                      .firstWhere((t) => t.isNotEmpty, orElse: () => '');
                  final room = subjectSlots
                      .map((s) => s.room ?? '')
                      .firstWhere((r) => r.isNotEmpty, orElse: () => '');
                  final days = subjectSlots
                      .map((s) => (s.dayOfWeek >= 1 && s.dayOfWeek <= 7)
                          ? dayNames[s.dayOfWeek]
                          : '')
                      .where((d) => d.isNotEmpty)
                      .toSet()
                      .join(', ');

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TimetablePage(user: user),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(Rad.md),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ac.surf,
                        borderRadius: BorderRadius.circular(Rad.md),
                        border: Border.all(color: ac.bdr),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: ac.surf2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: ac.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ac.txt,
                                  ),
                                ),
                                if (teacher.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    teacher,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: ac.primary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (room.isNotEmpty) room,
                                    if (days.isNotEmpty) days,
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: ac.txt2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
