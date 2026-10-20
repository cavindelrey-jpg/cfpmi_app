// lib/features/school/attendance_summary_page.dart
// Management monitor: per-student attendance over a date range for a class.
// Staff-only (same gate as recording). Read-aggregation over
// AttendanceRepository.getForClassRange.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/attendance_record.dart';
import '../../models/student_record.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/school_class_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_skeleton.dart';
import 'widgets/management_scaffold.dart';

class _Row {
  final String name;
  int present = 0, absent = 0, late = 0, excused = 0;
  _Row(this.name);
  int get total => present + absent + late + excused;
  int get rate => total == 0 ? 0 : (present / total * 100).round();
}

class AttendanceSummaryPage extends StatefulWidget {
  final AppUser user;
  const AttendanceSummaryPage({super.key, required this.user});
  @override
  State<AttendanceSummaryPage> createState() => _AttendanceSummaryPageState();
}

class _AttendanceSummaryPageState extends State<AttendanceSummaryPage> {
  AppColors get ac => AppColors.of(context);
  String get _schoolId => widget.user.effectiveSchoolId;
  final _roster = StudentRosterRepository.instance;
  final _repo = AttendanceRepository.instance;

  List<String> _classes = [];
  String? _class;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  List<_Row> _rows = [];
  bool _loading = true;

  bool get _canView =>
      widget.user.canRecordAnyMarks ||
      (widget.user.isSchoolMember && !widget.user.isStudent && !widget.user.isParent);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final res = await _roster.getStudents(_schoolId);
    final all = res is Success<List<StudentRecord>> ? res.value : <StudentRecord>[];
    final configured = await SchoolClassRepository.instance.getClassNames(_schoolId, activeOnly: true);
    final classes = <String>{
      ...configured,
      for (final s in all)
        if (s.classLevel.isNotEmpty) s.classLevel,
    }.toList()
      ..sort();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _class = classes.isNotEmpty ? classes.first : null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_class == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final rosterRes = await _roster.getStudents(_schoolId, classLevel: _class);
    final recRes = await _repo.getForClassRange(_schoolId, _class!, _range.start, _range.end);
    final students = rosterRes is Success<List<StudentRecord>> ? rosterRes.value : <StudentRecord>[];
    final recs = recRes is Success<List<AttendanceRecord>> ? recRes.value : <AttendanceRecord>[];

    final byId = {for (final s in students) s.id: _Row(s.name)};
    for (final r in recs) {
      final row = byId[r.studentId];
      if (row == null) continue;
      switch (r.status) {
        case AttendanceStatus.present:
          row.present++;
          break;
        case AttendanceStatus.absent:
          row.absent++;
          break;
        case AttendanceStatus.late:
          row.late++;
          break;
        case AttendanceStatus.excused:
          row.excused++;
          break;
      }
    }
    if (!mounted) return;
    setState(() {
      _rows = byId.values.toList()..sort((a, b) => a.rate.compareTo(b.rate)); // lowest attendance first
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance summary')),
        body: Center(child: Text('Not permitted.', style: GoogleFonts.inter(color: ac.txt2))),
      );
    }
    return ManagementScaffold(
      title: 'Attendance Summary',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
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
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      '${AttendanceRecord.dateKey(_range.start).substring(5)} – ${AttendanceRecord.dateKey(_range.end).substring(5)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const SkeletonList();
    if (_rows.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text('No students in this class.', style: GoogleFonts.inter(color: ac.txt2)),
      ));
    }
    final recorded = _rows.where((r) => r.total > 0).toList();
    final avg = recorded.isEmpty ? 0 : (recorded.map((r) => r.rate).reduce((a, b) => a + b) / recorded.length).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.groups_rounded, color: ac.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Class average attendance',
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2))),
            Text('$avg%', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: ac.primary)),
          ]),
        ),
        const SizedBox(height: 10),
        for (final r in _rows) _rowTile(r),
      ],
    );
  }

  Widget _rowTile(_Row r) {
    final color = r.total == 0 ? ac.muted : (r.rate >= 75 ? ac.grn : (r.rate >= 50 ? ac.org : ac.red));
    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
                Text(r.total == 0
                    ? 'No sessions recorded'
                    : 'P ${r.present} · A ${r.absent} · L ${r.late} · E ${r.excused}',
                    style: GoogleFonts.inter(fontSize: 11, color: ac.txt2)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(r.total == 0 ? '—' : '${r.rate}%',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }
}
