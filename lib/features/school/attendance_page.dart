// lib/features/school/attendance_page.dart
// Teacher/staff daily attendance register: pick a class + date, mark each
// student present/absent/late/excused, save. Re-opening the same class+date
// loads the saved register back (upsert, no duplicates). Backed by
// AttendanceRepository -> public.attendance_records.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/attendance_record.dart';
import '../../models/student_record.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../core/result.dart';
import '../../theme/app_colors.dart';
import 'widgets/management_scaffold.dart';

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
      (widget.user.isSchoolMember && !widget.user.isStudent && !widget.user.isParent);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Derive the class list from the school roster so this works for both
    // class teachers and admins without depending on teaching assignments.
    final res = await _roster.getStudents(_schoolId);
    final all = res is Success<List<StudentRecord>> ? res.value : <StudentRecord>[];
    final classes = <String>{for (final s in all) if (s.classLevel.isNotEmpty) s.classLevel}.toList()
      ..sort();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _class = (widget.initialClass != null && classes.contains(widget.initialClass))
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
    final existingRes = await _repo.getForClassDate(_schoolId, _class!, _date);

    final students = rosterRes is Success<List<StudentRecord>> ? rosterRes.value : <StudentRecord>[];
    final existing = existingRes is Success<List<AttendanceRecord>>
        ? {for (final r in existingRes.value) r.studentId: r.status}
        : <String, AttendanceStatus>{};

    if (!mounted) return;
    setState(() {
      _students = students;
      _status
        ..clear()
        // Default everyone to present, then overlay any saved marks.
        ..addEntries(students.map((s) => MapEntry(s.id, existing[s.id] ?? AttendanceStatus.present)));
      if (existingRes is Failure<List<AttendanceRecord>>) _error = existingRes.friendlyMessage;
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
        .map((s) => AttendanceRecord(
              id: '',
              schoolId: _schoolId,
              classLevel: _class!,
              sessionDate: _date,
              studentId: s.id,
              studentName: s.name,
              status: _status[s.id] ?? AttendanceStatus.present,
              recordedBy: widget.user.name,
            ))
        .toList();
    final res = await _repo.saveBatch(records);
    if (!mounted) return;
    setState(() => _saving = false);
    final ok = res is Success<void>;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Attendance saved for $_class · ${AttendanceRecord.dateKey(_date)}'
          : (res as Failure<void>).friendlyMessage),
      backgroundColor: ok ? ac.grn : ac.red,
    ));
  }

  int _count(AttendanceStatus s) => _status.values.where((v) => v == s).length;

  @override
  Widget build(BuildContext context) {
    if (!_canRecord) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('You do not have permission to record attendance.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(color: ac.txt2)),
          ),
        ),
      );
    }

    return ManagementScaffold(
      title: 'Attendance Register',
      floatingActionButton: (_class != null && _students.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: ac.primary,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(_saving ? 'Saving…' : 'Save register',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: Column(
        children: [
          _controls(),
          if (_error != null)
            Container(
              width: double.infinity,
              color: ac.redBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: ac.red)),
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
                  decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                  items: [for (final c in _classes) DropdownMenuItem(value: c, child: Text(c))],
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
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
          if (_class != null && _students.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _summaryChip('Present', _count(AttendanceStatus.present), ac.grn),
                _summaryChip('Absent', _count(AttendanceStatus.absent), ac.red),
                _summaryChip('Late', _count(AttendanceStatus.late), ac.org),
                _summaryChip('Excused', _count(AttendanceStatus.excused), ac.blu),
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
              Text('$n', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: ac.txt2)),
            ],
          ),
        ),
      );

  Widget _registerBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_class == null || _classes.isEmpty) {
      return _empty('No classes with students yet.', 'Add students to the roster first, then take attendance.');
    }
    if (_students.isEmpty) {
      return _empty('No students in $_class.', 'Add students to this class on the roster.');
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
                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ac.txt)),
                    if (s.matricule != null && s.matricule!.isNotEmpty)
                      Text(s.matricule!, style: GoogleFonts.inter(fontSize: 11, color: ac.txt2)),
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
                color: current == status ? color : color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: current == status ? color : Colors.transparent),
              ),
              child: Center(
                child: Text(letter,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: current == status ? Colors.white : color)),
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
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
            ],
          ),
        ),
      );
}
