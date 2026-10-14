// lib/features/classroom/student_classroom_page.dart
// Student View (mobile). Joins the live class for the student's own class,
// then shows three layers: the live Presentation (synced slide), private
// My Notes (stored locally — never uploaded), and Resources (only those the
// teacher has RELEASED; hidden/teacher-only never appear here even if the
// file was pre-cached).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../repositories/classroom_repository.dart';
import '../../theme/app_colors.dart';
import 'classroom_slide.dart';

class StudentClassroomPage extends StatelessWidget {
  final AppUser user;
  const StudentClassroomPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final schoolId = user.schoolId ?? '';
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(title: const Text('Live Class')),
      body: StreamBuilder<ClassroomSession?>(
        stream: ClassroomRepository.instance.watchLiveForClass(schoolId, user.classLevel),
        builder: (context, snap) {
          final s = snap.data;
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sensors_off_rounded, size: 52, color: ac.muted),
                  const SizedBox(height: 12),
                  Text('No live class right now',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
                  const SizedBox(height: 6),
                  Text('When your teacher starts a class for ${user.classLevel.isEmpty ? 'your class' : user.classLevel}, it will appear here.',
                      textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
                ]),
              ),
            );
          }
          return _LiveClass(user: user, session: s);
        },
      ),
    );
  }
}

class _LiveClass extends StatelessWidget {
  final AppUser user;
  final ClassroomSession session;
  const _LiveClass({required this.user, required this.session});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // LIVE banner
          Container(
            width: double.infinity,
            color: ac.red.withValues(alpha: 0.08),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: ac.red, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('LIVE CLASS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: ac.red)),
              const Spacer(),
              Flexible(
                child: Text(
                  '${session.teacherName.isEmpty ? 'Teacher' : session.teacherName} · ${session.subject}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                ),
              ),
            ]),
          ),
          if (session.topic.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(session.topic,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt)),
              ),
            ),
          TabBar(
            labelColor: ac.primary,
            unselectedLabelColor: ac.txt2,
            indicatorColor: ac.primary,
            tabs: const [
              Tab(text: 'Presentation'),
              Tab(text: 'My Notes'),
              Tab(text: 'Resources'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _presentation(ac),
              _MyNotes(sessionId: session.id, userId: user.id),
              _Resources(sessionId: session.id, sessionEnded: session.status == ClassroomStatus.ended),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _presentation(AppColors ac) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClassroomSlide(
                  url: session.currentSlideUrl, index: session.currentSlide, total: session.slideCount, topic: session.topic),
            ),
            const SizedBox(height: 10),
            Text(session.slideCount == 0 ? 'Waiting for the teacher…' : 'Slide ${session.currentSlide + 1} of ${session.slideCount}',
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          ],
        ),
      );
}

class _MyNotes extends StatefulWidget {
  final String sessionId;
  final String userId;
  const _MyNotes({required this.sessionId, required this.userId});
  @override
  State<_MyNotes> createState() => _MyNotesState();
}

class _MyNotesState extends State<_MyNotes> {
  final _ctrl = TextEditingController();
  String get _key => 'classroom_notes_${widget.sessionId}_${widget.userId}';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ctrl.text = prefs.getString(_key) ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save(String v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: ac.txt2),
            const SizedBox(width: 6),
            Text('Private — saved on this device only',
                style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: _save,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Type your notes for this lesson…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: ac.surf,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resources extends StatelessWidget {
  final String sessionId;
  final bool sessionEnded;
  const _Resources({required this.sessionId, required this.sessionEnded});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<ClassroomResource>>(
      stream: ClassroomRepository.instance.watchResources(sessionId),
      builder: (context, snap) {
        final all = snap.data ?? const <ClassroomResource>[];
        // Only what the teacher has released (after_class items appear once
        // the lesson has ended). Hidden / teacher-only never show here.
        final visible = all.where((r) =>
            r.visibility == ResourceVisibility.released ||
            (r.visibility == ResourceVisibility.afterClass && sessionEnded)).toList();
        if (visible.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text('No resources released yet.\nYour teacher will share materials during the lesson.',
                  textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: ac.txt2)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = visible[i];
            return InkWell(
              onTap: () => _open(context, r),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(_iconFor(r.kind), color: ac.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(r.title.isEmpty ? r.kind : r.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
                  ),
                  Icon(Icons.open_in_new_rounded, size: 18, color: ac.muted),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _open(BuildContext context, ClassroomResource r) async {
    if (r.url.isEmpty) return;
    final uri = Uri.tryParse(r.url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this resource.')));
      }
    }
  }

  IconData _iconFor(String kind) => switch (kind) {
        'pdf' => Icons.picture_as_pdf_outlined,
        'image' => Icons.image_outlined,
        'video' => Icons.play_circle_outline_rounded,
        'pptx' => Icons.slideshow_outlined,
        'link' => Icons.link_rounded,
        _ => Icons.description_outlined,
      };
}
