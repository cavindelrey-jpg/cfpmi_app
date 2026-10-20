// lib/features/school/attendance_page.dart
// Unified Attendance Workspace inside ApplicationShell:
// - Staff / Teachers / Admins: Full interactive daily attendance register
//   (pick a class + date, mark each student Present/Absent/Late/Excused, save
//   via AttendanceRepository.saveBatch, and open AttendanceSummaryPage).
// - Students: Real read-only attendance log and attendance rate calculated
//   from AttendanceRepository.getForStudent(user.id).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/attendance_record.dart';
import '../../models/student_record.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/application_shell.dart';
import 'attendance_summary_page.dart';

class AttendancePage extends StatefulWidget {
  final AppUser user;
  final String? initialClass;
  const AttendancePage({super.key, required this.user, this.initialClass});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  AppColors get ac => AppColors.of(context);
  String get _schoolId => widget.user.schoolId ?? '';

  final _repo = AttendanceRepository.instance;
  final _roster = StudentRosterRepository.instance;

  List<String> _classes = [];
  String? _class;
  DateTime _date = DateTime.now();

  List<StudentRecord> _students = [];
  final Map<String, AttendanceStatus> _status = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canRecord =>
      widget.user.canRecordAnyMarks ||
      (widget.user.isSchoolMember &&
          !widget.user.isStudent &&
          !widget.user.isParent);

  @override
  void initState() {
    super.initState();
    if (_canRecord) {
      _bootstrap();
    } else {
      _loading = false;
    }
  }

  Future<void> _bootstrap() async {
    final res = await _roster.getStudents(_schoolId);
    final all = res is Success<List<StudentRecord>>
        ? res.value
        : <StudentRecord>[];
    final classes = <String>{
      for (final s in all)
        if (s.classLevel.isNotEmpty) s.classLevel,
    }.toList()
      ..sort();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _class = (widget.initialClass != null &&
              classes.contains(widget.initialClass))
          ? widget.initialClass
          : (classes.isNotEmpty ? classes.first : null);
    });
    await _loadRegister();
  }

  Future<void> _loadRegister() async {
    if (_class == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final rosterRes = await _roster.getStudents(_schoolId, classLevel: _class);
    final existingRes =
        await _repo.getForClassDate(_schoolId, _class!, _date);

    final students = rosterRes is Success<List<StudentRecord>>
        ? rosterRes.value
        : <StudentRecord>[];
    final existing = existingRes is Success<List<AttendanceRecord>>
        ? {for (final r in existingRes.value) r.studentId: r.status}
        : <String, AttendanceStatus>{};

    if (!mounted) return;
    setState(() {
      _students = students;
      _status
        ..clear()
        ..addEntries(
          students.map(
            (s) => MapEntry(s.id, existing[s.id] ?? AttendanceStatus.present),
          ),
        );
      if (existingRes is Failure<List<AttendanceRecord>>) {
        _error = existingRes.friendlyMessage;
      }
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _loadRegister();
    }
  }

  Future<void> _save() async {
    if (_class == null || _students.isEmpty) return;
    setState(() => _saving = true);
    final records = _students
        .map(
          (s) => AttendanceRecord(
            id: '',
            schoolId: _schoolId,
            classLevel: _class!,
            sessionDate: _date,
            studentId: s.id,
            studentName: s.name,
            status: _status[s.id] ?? AttendanceStatus.present,
            recordedBy: widget.user.name,
          ),
        )
        .toList();
    final res = await _repo.saveBatch(records);
    if (!mounted) return;
    setState(() => _saving = false);
    final ok = res is Success<void>;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Attendance saved for $_class · ${AttendanceRecord.dateKey(_date)}'
              : (res as Failure<void>).friendlyMessage,
        ),
        backgroundColor: ok ? ac.grn : ac.red,
      ),
    );
  }

  int _count(AttendanceStatus s) => _status.values.where((v) => v == s).length;

  @override
  Widget build(BuildContext context) {
    if (!_canRecord) {
      return ApplicationShell(
        user: widget.user,
        currentTitle: 'Attendance',
        subtitle: 'Personal attendance records and session history',
        currentDestination: AppNavDestination.attendance,
        child: _StudentAttendanceView(user: widget.user),
      );
    }

    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Attendance Register',
      subtitle: 'Record daily class attendance and view class summaries',
      currentDestination: AppNavDestination.attendance,
      headerActions: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AttendanceSummaryPage(user: widget.user),
              ),
            );
          },
          icon: const Icon(Icons.analytics_outlined, size: 16),
          label: const Text('Class Summary'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (_class != null && _students.isNotEmpty) ...[
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(_saving ? 'Saving…' : 'Save Register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ac.primary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
      floatingActionButton: (_class != null && _students.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: ac.primary,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _saving ? 'Saving…' : 'Save register',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      child: Column(
        children: [
          _controls(),
          if (_error != null)
            Container(
              width: double.infinity,
              color: ac.redBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12, color: ac.red),
              ),
            ),
          const Divider(height: 1),
          Expanded(child: _registerBody()),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _class,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in _classes)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    setState(() => _class = v);
                    _loadRegister();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(AttendanceRecord.dateKey(_date)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          if (_class != null && _students.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _summaryChip(
                  'Present',
                  _count(AttendanceStatus.present),
                  ac.grn,
                ),
                _summaryChip(
                  'Absent',
                  _count(AttendanceStatus.absent),
                  ac.red,
                ),
                _summaryChip('Late', _count(AttendanceStatus.late), ac.org),
                _summaryChip(
                  'Excused',
                  _count(AttendanceStatus.excused),
                  ac.blu,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int n, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '$n',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: ac.txt2),
              ),
            ],
          ),
        ),
      );

  Widget _registerBody() {
    if (_loading) return const SkeletonList();
    if (_class == null || _classes.isEmpty) {
      return _empty(
        'No classes with students yet.',
        'Add students to the school roster first, then take attendance.',
      );
    }
    if (_students.isEmpty) {
      return _empty(
        'No students in $_class.',
        'Add students to this class on the roster.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final s = _students[i];
        final st = _status[s.id] ?? AttendanceStatus.present;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ac.bdr),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ac.txt,
                      ),
                    ),
                    if (s.matricule != null && s.matricule!.isNotEmpty)
                      Text(
                        s.matricule!,
                        style: GoogleFonts.inter(fontSize: 11, color: ac.txt2),
                      ),
                  ],
                ),
              ),
              _statusToggle(s.id, st),
            ],
          ),
        );
      },
    );
  }

  Widget _statusToggle(String studentId, AttendanceStatus current) {
    final opts = <(AttendanceStatus, String, Color)>[
      (AttendanceStatus.present, 'P', ac.grn),
      (AttendanceStatus.absent, 'A', ac.red),
      (AttendanceStatus.late, 'L', ac.org),
      (AttendanceStatus.excused, 'E', ac.blu),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (status, letter, color) in opts)
          GestureDetector(
            onTap: () => setState(() => _status[studentId] = status),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: current == status
                    ? color
                    : color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: current == status ? color : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: current == status ? Colors.white : color,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(String title, String subtitle) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined, size: 48, color: ac.muted),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
              ),
            ],
          ),
        ),
      );
}

class _StudentAttendanceView extends StatefulWidget {
  final AppUser user;
  const _StudentAttendanceView({required this.user});

  @override
  State<_StudentAttendanceView> createState() => _StudentAttendanceViewState();
}

class _StudentAttendanceViewState extends State<_StudentAttendanceView> {
  AppColors get ac => AppColors.of(context);
  List<AttendanceRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.user.isGuest || widget.user.id.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final res = await AttendanceRepository.instance.getForStudent(widget.user.id);
    if (!mounted) return;
    setState(() {
      _records = res is Success<List<AttendanceRecord>> ? res.value : [];
      _loading = false;
    });
  }

  int _count(AttendanceStatus s) =>
      _records.where((r) => r.status == s).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList();
    if (widget.user.isGuest || widget.user.id.isEmpty) {
      return _emptyState(
        'Sign in to view your attendance',
        'Connect your student account to see your recorded class attendance.',
      );
    }
    if (_records.isEmpty) {
      return _emptyState(
        'No attendance recorded yet.',
        'Your teachers have not marked any attendance sessions for you so far.',
      );
    }
    final total = _records.length;
    final present = _count(AttendanceStatus.present);
    final rate = total == 0 ? 0 : (present / total * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF081630), Color(0xFF142B58)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$rate%',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5A93C),
                    ),
                  ),
                  Text(
                    'Overall Attendance Rate',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _miniStat('Present', _count(AttendanceStatus.present)),
              _miniStat('Absent', _count(AttendanceStatus.absent)),
              _miniStat('Late', _count(AttendanceStatus.late)),
              _miniStat('Excused', _count(AttendanceStatus.excused)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'SESSION HISTORY (${_records.length})',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ac.txt2,
          ),
        ),
        const SizedBox(height: 10),
        for (final r in _records) _attendanceRow(r),
      ],
    );
  }

  Widget _miniStat(String label, int n) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          children: [
            Text(
              '$n',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );

  Widget _attendanceRow(AttendanceRecord r) {
    final color = switch (r.status) {
      AttendanceStatus.present => ac.grn,
      AttendanceStatus.absent => ac.red,
      AttendanceStatus.late => ac.org,
      AttendanceStatus.excused => ac.blu,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ac.bdr),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AttendanceRecord.dateKey(r.sessionDate),
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ac.txt,
                  ),
                ),
                Text(
                  r.subject.isEmpty
                      ? r.classLevel
                      : '${r.classLevel} · ${r.subject}',
                  style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              r.status.label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined, size: 48, color: ac.muted),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
              ),
            ],
          ),
        ),
      );
}
