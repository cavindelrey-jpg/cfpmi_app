// lib/features/classroom/classroom_teacher_page.dart
// Teacher Control View (laptop/web). Lists the teacher's class sessions and
// opens the control panel: slide navigation + the resource RELEASE controls.
// The control panel is private to the teacher; the TV shows ClassroomDisplayPage.

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/student_record.dart';
import '../../repositories/classroom_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../services/classroom_upload_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/application_shell.dart';
import 'classroom_display_page.dart';
import 'classroom_slide.dart';
import '../academic_content/content_viewer_page.dart';

class ClassroomTeacherPage extends StatefulWidget {
  final AppUser user;
  const ClassroomTeacherPage({super.key, required this.user});
  @override
  State<ClassroomTeacherPage> createState() => _ClassroomTeacherPageState();
}

class _ClassroomTeacherPageState extends State<ClassroomTeacherPage> {
  AppColors get ac => AppColors.of(context);
  String get _schoolId => widget.user.schoolId ?? '';
  final _repo = ClassroomRepository.instance;

  List<ClassroomSession> _sessions = [];
  bool _loading = true;

  bool get _canTeach =>
      widget.user.canRecordAnyMarks ||
      (widget.user.isSchoolMember && !widget.user.isStudent && !widget.user.isParent);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _repo.listForTeacher(_schoolId, widget.user.id);
    if (!mounted) return;
    setState(() {
      _sessions = res is Success<List<ClassroomSession>> ? res.value : [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_canTeach) {
      return ApplicationShell(
        user: widget.user,
        currentTitle: 'Classroom',
        currentDestination: AppNavDestination.classroom,
        child: Center(
          child: Text(
            'Only teachers can run a classroom.',
            style: GoogleFonts.inter(color: ac.txt2),
          ),
        ),
      );
    }
    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Classroom Sessions',
      subtitle: 'Start a live presentation or manage lesson resources',
      currentDestination: AppNavDestination.classroom,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startClassDialog,
        icon: const Icon(Icons.cast_rounded),
        label: const Text('Start Class'),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _sessionTile(_sessions[i]),
                ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cast_for_education_rounded, size: 52, color: ac.muted),
            const SizedBox(height: 12),
            Text('No classes yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 6),
            Text('Tap "Start Class" to begin a live lesson on the projector.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          ]),
        ),
      );

  Widget _sessionTile(ClassroomSession s) {
    final live = s.status == ClassroomStatus.live;
    final color = live ? ac.red : (s.status == ClassroomStatus.ended ? ac.muted : ac.primary);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ClassroomControlPage(user: widget.user, sessionId: s.id))).then((_) => _load()),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.bdr)),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(live ? Icons.sensors_rounded : Icons.slideshow_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.classLevel} · ${s.subject}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
                Text(s.topic.isEmpty ? '${s.slideCount} slides' : s.topic,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(live ? 'LIVE' : s.status.name,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startClassDialog() async {
    final rosterRes = await StudentRosterRepository.instance.getStudents(_schoolId);
    final students = rosterRes is Success<List<StudentRecord>> ? rosterRes.value : <StudentRecord>[];
    final classes = <String>{for (final s in students) if (s.classLevel.isNotEmpty) s.classLevel}.toList()..sort();
    if (!mounted) return;

    String? cls = classes.isNotEmpty ? classes.first : null;
    final subjectCtrl = TextEditingController();
    final topicCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Start Class'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (classes.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: cls,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                  items: [for (final c in classes) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setD(() => cls = v),
                )
              else
                TextField(
                  decoration: const InputDecoration(labelText: 'Class (e.g. Form 5A)', border: OutlineInputBorder()),
                  onChanged: (v) => cls = v,
                ),
              const SizedBox(height: 10),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: topicCtrl, decoration: const InputDecoration(labelText: 'Topic', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (created != true || cls == null || cls!.isEmpty) return;
    final session = ClassroomSession(
      id: '',
      schoolId: _schoolId,
      classLevel: cls!,
      subject: subjectCtrl.text.trim(),
      topic: topicCtrl.text.trim(),
      teacherId: widget.user.id,
      teacherName: widget.user.name,
    );
    final res = await _repo.createSession(session);
    if (!mounted) return;
    if (res is Success<String>) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ClassroomControlPage(user: widget.user, sessionId: res.value))).then((_) => _load());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((res as Failure<String>).friendlyMessage)));
    }
  }
}

// ── Teacher control panel for one session ────────────────────────────
class ClassroomControlPage extends StatelessWidget {
  final AppUser user;
  final String sessionId;
  const ClassroomControlPage({super.key, required this.user, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final repo = ClassroomRepository.instance;
    return StreamBuilder<ClassroomSession?>(
      stream: repo.watchSession(sessionId),
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) {
          return ApplicationShell(
            user: user,
            currentTitle: 'Classroom Control',
            currentDestination: AppNavDestination.classroom,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return ApplicationShell(
          user: user,
          currentTitle: '${s.classLevel} · ${s.subject}',
          subtitle: s.topic,
          currentDestination: AppNavDestination.classroom,
          headerActions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClassroomDisplayPage(sessionId: sessionId),
                ),
              ),
              icon: const Icon(Icons.tv_rounded, size: 16),
              label: const Text('Projector Display'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // ── AREA 1: PROJECTED LESSON ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ac.surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ac.bdr),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ac.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.cast_for_education_rounded, color: ac.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Area 1: Projected Lesson',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt),
                              ),
                              Text(
                                'Multi-page presentation or slide deck shown on the classroom projector screen',
                                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClassroomDisplayPage(sessionId: sessionId),
                            ),
                          ),
                          icon: const Icon(Icons.tv_rounded, size: 16),
                          label: const Text('Open Projector Screen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF081630),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Slide Preview
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClassroomSlide(
                        url: s.currentSlideUrl,
                        index: s.currentSlide,
                        total: s.slideCount,
                        topic: s.topic,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Slide Stepper Controls
                    Row(
                      children: [
                        _ctrlBtn(
                          ac,
                          Icons.chevron_left_rounded,
                          'Previous Slide',
                          s.currentSlide > 0
                              ? () => repo.setCurrentSlide(sessionId, s.currentSlide - 1)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Slide ${s.slideCount == 0 ? 1 : s.currentSlide + 1} of ${s.slideCount == 0 ? 1 : s.slideCount}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: ac.txt),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ctrlBtn(
                          ac,
                          Icons.chevron_right_rounded,
                          'Next Slide',
                          s.currentSlide < s.slideCount - 1
                              ? () => repo.setCurrentSlide(sessionId, s.currentSlide + 1)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Actions Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _attachPresentation(context, s),
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(
                            (s.originalFile ?? '').isEmpty
                                ? 'Upload Presentation (PDF / PowerPoint)'
                                : 'Replace Presentation Document',
                          ),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _uploadSlideImages(context, s),
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                          label: const Text('Upload Slide Images'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        if ((s.originalFile ?? '').isNotEmpty)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: ac.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              final url = s.originalFile!;
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ContentViewerPage(
                                  fileUrl: url,
                                  title: 'Presentation',
                                  kind: viewableKindFor(url) ?? ViewableFileKind.pptx,
                                ),
                              ));
                            },
                            icon: const Icon(Icons.slideshow_rounded, size: 16),
                            label: const Text('Preview Lesson'),
                          ),
                        s.status == ClassroomStatus.live
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ac.red,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => repo.endSession(sessionId),
                                icon: const Icon(Icons.stop_rounded, size: 16),
                                label: const Text('End Live Lesson'),
                              )
                            : FilledButton.icon(
                                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => repo.startSession(sessionId),
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Start Live Lesson'),
                              ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── AREA 2: STUDENT RESOURCES ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ac.surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ac.bdr),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.folder_shared_rounded, color: Color(0xFFE5A93C), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Area 2: Student Resources',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt),
                              ),
                              Text(
                                'Reference materials, formula sheets, and homework sheets. Kept separate from projected slides.',
                                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _addResourceDialog(context, s),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Resource'),
                          style: FilledButton.styleFrom(
                            backgroundColor: ac.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ResourceControlList(sessionId: sessionId, ac: ac),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ctrlBtn(AppColors ac, IconData icon, String tip, VoidCallback? onTap) => Material(
        color: onTap == null ? ac.surf2 : ac.primary,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, color: onTap == null ? ac.muted : Colors.white, size: 28),
        ),
      );

  void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addSlidesDialog(BuildContext context, ClassroomSession s) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Upload slide images'),
            subtitle: const Text('Pick the slides (export from PowerPoint as PNG/JPG). They sync live.'),
            onTap: () => Navigator.pop(ctx, 'upload'),
          ),
          ListTile(
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('Attach PowerPoint / PDF'),
            subtitle: const Text('Stored with the lesson for download.'),
            onTap: () => Navigator.pop(ctx, 'attach'),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Paste image URLs'),
            onTap: () => Navigator.pop(ctx, 'urls'),
          ),
        ]),
      ),
    );
    if (choice == 'upload') {
      await _uploadSlideImages(context, s);
    } else if (choice == 'attach') {
      await _attachPresentation(context, s);
    } else if (choice == 'urls') {
      await _slideUrlsDialog(context, s);
    }
  }

  Future<Uint8List?> _readPlatformBytes(PlatformFile f) async {
    if (f.bytes != null && f.bytes!.isNotEmpty) return f.bytes;
    if (f.path != null && f.path!.isNotEmpty) {
      try {
        final file = File(f.path!);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _uploadSlideImages(BuildContext context, ClassroomSession s) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (res == null || res.files.isEmpty) return;
    _toast(context, 'Uploading ${res.files.length} slide(s)…');
    final files = res.files.toList()..sort((a, b) => a.name.compareTo(b.name));
    final urls = <String>[...s.slideUrls];
    var failed = 0;
    for (final f in files) {
      final bytes = await _readPlatformBytes(f);
      if (bytes == null) {
        failed++;
        continue;
      }
      final up = await ClassroomUploadService.instance.uploadBytes(bytes: bytes, filename: f.name, schoolId: s.schoolId);
      if (up is Success<String>) {
        urls.add(up.value);
      } else {
        failed++;
      }
    }
    await ClassroomRepository.instance.setSlides(sessionId, urls);
    _toast(context, failed == 0 ? 'Slides updated (${urls.length}).' : 'Added ${urls.length - s.slideUrls.length} slide(s); $failed failed.');
  }

  Future<void> _attachPresentation(BuildContext context, ClassroomSession s) async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pptx', 'ppt', 'pdf'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = await _readPlatformBytes(f);
    if (bytes == null) {
      _toast(context, 'Could not read presentation file: ${f.name}');
      return;
    }
    _toast(context, 'Uploading presentation ${f.name}…');
    final up = await ClassroomUploadService.instance.uploadBytes(bytes: bytes, filename: f.name, schoolId: s.schoolId);
    if (up is Success<String>) {
      await ClassroomRepository.instance.setOriginalFile(sessionId, up.value);
      if (s.slideUrls.isEmpty) {
        await ClassroomRepository.instance.setSlides(sessionId, [up.value]);
      }
      _toast(context, 'Presentation attached to projected lesson.');
    } else {
      _toast(context, (up as Failure<String>).friendlyMessage);
    }
  }

  Future<void> _slideUrlsDialog(BuildContext context, ClassroomSession s) async {
    final ctrl = TextEditingController(text: s.slideUrls.join('\n'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slides (one image URL per line)'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'https://…/slide1.png\nhttps://…/slide2.png',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final urls = ctrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await ClassroomRepository.instance.setSlides(sessionId, urls);
    }
  }

  Future<void> _addResourceDialog(BuildContext context, ClassroomSession s) async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String kind = 'document';
    bool uploading = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add resource'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'File URL / link', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          final r = await FilePicker.platform.pickFiles(withData: true);
                          if (r == null || r.files.isEmpty) return;
                          final f = r.files.first;
                          final bytes = await _readPlatformBytes(f);
                          if (bytes == null) {
                            _toast(context, 'Could not read file: ${f.name}');
                            return;
                          }
                          setD(() => uploading = true);
                          final up = await ClassroomUploadService.instance
                              .uploadBytes(bytes: bytes, filename: f.name, schoolId: s.schoolId);
                          final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
                          setD(() {
                            uploading = false;
                            if (up is Success<String>) {
                              urlCtrl.text = up.value;
                              kind = ClassroomUploadService.kindForExt(ext);
                              if (titleCtrl.text.trim().isEmpty) titleCtrl.text = f.name;
                            }
                          });
                        },
                  icon: uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(uploading ? 'Uploading…' : 'Upload file'),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'document', child: Text('Document')),
                  DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                  DropdownMenuItem(value: 'image', child: Text('Image')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'pptx', child: Text('PowerPoint')),
                  DropdownMenuItem(value: 'link', child: Text('Link')),
                ],
                onChanged: (v) => setD(() => kind = v ?? 'document'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      await ClassroomRepository.instance.addResource(ClassroomResource(
        id: '', sessionId: sessionId, schoolId: s.schoolId,
        title: titleCtrl.text.trim(), kind: kind, url: urlCtrl.text.trim(),
        visibility: ResourceVisibility.hidden,
      ));
    }
  }
}

class _ResourceControlList extends StatelessWidget {
  final String sessionId;
  final AppColors ac;
  const _ResourceControlList({required this.sessionId, required this.ac});

  @override
  Widget build(BuildContext context) {
    final repo = ClassroomRepository.instance;
    return StreamBuilder<List<ClassroomResource>>(
      stream: repo.watchResources(sessionId),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No resources yet. Add a diagram, PDF or question to release in class.',
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          );
        }
        return Column(
          children: [
            for (final r in items)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
                child: Row(children: [
                  Icon(_iconFor(r.kind), color: ac.txt2, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
                      Text(r.visibility.label,
                          style: GoogleFonts.inter(fontSize: 11, color: _visColor(r.visibility))),
                    ]),
                  ),
                  if (r.visibility == ResourceVisibility.released)
                    OutlinedButton(
                      onPressed: () => repo.setVisibility(r.id, ResourceVisibility.hidden),
                      child: const Text('Hide'))
                  else
                    FilledButton(
                      onPressed: () => repo.setVisibility(r.id, ResourceVisibility.released),
                      child: const Text('Release')),
                ]),
              ),
          ],
        );
      },
    );
  }

  Color _visColor(ResourceVisibility v) => switch (v) {
        ResourceVisibility.released => ac.grn,
        ResourceVisibility.teacherOnly => ac.red,
        ResourceVisibility.afterClass => ac.org,
        ResourceVisibility.hidden => ac.txt2,
      };

  IconData _iconFor(String kind) => switch (kind) {
        'pdf' => Icons.picture_as_pdf_outlined,
        'image' => Icons.image_outlined,
        'video' => Icons.play_circle_outline_rounded,
        'pptx' => Icons.slideshow_outlined,
        'link' => Icons.link_rounded,
        _ => Icons.description_outlined,
      };
}
