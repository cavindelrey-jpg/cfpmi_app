// lib/features/school/disciplinary_records_page.dart
// School administration student disciplinary records management page.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/disciplinary_record.dart';
import '../../models/student_record.dart';
import '../../repositories/disciplinary_repository.dart';
import '../../repositories/school_class_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../services/sms_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/application_shell.dart';
import '../../widgets/widgets.dart';

class DisciplinaryRecordsPage extends StatefulWidget {
  final AppUser user;
  const DisciplinaryRecordsPage({super.key, required this.user});

  @override
  State<DisciplinaryRecordsPage> createState() => _DisciplinaryRecordsPageState();
}

class _DisciplinaryRecordsPageState extends State<DisciplinaryRecordsPage> {
  final _repo = DisciplinaryRepository.instance;
  final _rosterRepo = StudentRosterRepository.instance;

  String get _schoolId => widget.user.effectiveSchoolId;

  List<DisciplinaryRecord> _records = [];
  List<StudentRecord> _students = [];
  String? _selectedClass;
  bool _loading = true;

  List<String> _classes = [
    'Form 1',
    'Form 2',
    'Form 3',
    'Form 4',
    'Form 5',
    'Lower Sixth',
    'Upper Sixth',
  ];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _load();
  }

  Future<void> _loadClasses() async {
    final list = await SchoolClassRepository.instance.getClassNames(_schoolId, activeOnly: true);
    if (mounted && list.isNotEmpty) {
      setState(() => _classes = list);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _repo.getRecords(_schoolId, classLevel: _selectedClass);
    final rosterRes = await _rosterRepo.getStudents(_schoolId, classLevel: _selectedClass);

    if (!mounted) return;
    setState(() {
      _records = res is Success<List<DisciplinaryRecord>> ? res.value : [];
      _students = rosterRes is Success<List<StudentRecord>> ? rosterRes.value : [];
      _loading = false;
    });
  }

  Future<void> _addIncidentDialog() async {
    final studentCtrl = TextEditingController();
    final infractionCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    String classLevel = _selectedClass ?? _classes.first;
    DisciplinarySeverity severity = DisciplinarySeverity.minor;
    DisciplinaryAction action = DisciplinaryAction.verbalWarning;
    bool notifyParent = true;
    DateTime incidentDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Log Disciplinary Incident', style: AppText.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: classLevel,
                  decoration: const InputDecoration(labelText: 'Class Level', border: OutlineInputBorder()),
                  items: [
                    for (final c in _classes) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => classLevel = v);
                  },
                ),
                const SizedBox(height: 12),
                if (_students.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Student', border: OutlineInputBorder()),
                    items: [
                      for (final s in _students)
                        DropdownMenuItem(value: s.name, child: Text(s.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        studentCtrl.text = v;
                        final match = _students.firstWhere((s) => s.name == v, orElse: () => _students.first);
                        if (match.parentContact != null) phoneCtrl.text = match.parentContact!;
                      }
                    },
                  ),
                if (_students.isNotEmpty) const SizedBox(height: 12),
                TextField(
                  controller: studentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student Name *',
                    hintText: 'e.g. Nafa Ismail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: infractionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Infraction / Behavior *',
                    hintText: 'e.g. Repeated Tardiness, Classroom Disruption',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DisciplinarySeverity>(
                  value: severity,
                  decoration: const InputDecoration(labelText: 'Severity Level', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: DisciplinarySeverity.minor, child: Text('Minor (Warning)')),
                    DropdownMenuItem(value: DisciplinarySeverity.moderate, child: Text('Moderate (Detention)')),
                    DropdownMenuItem(value: DisciplinarySeverity.severe, child: Text('Severe (Suspension/Hearing)')),
                  ],
                  onChanged: (v) => setD(() => severity = v ?? DisciplinarySeverity.minor),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DisciplinaryAction>(
                  value: action,
                  decoration: const InputDecoration(labelText: 'Action Taken', border: OutlineInputBorder()),
                  items: [
                    for (final a in DisciplinaryAction.values)
                      DropdownMenuItem(value: a, child: Text(a.label)),
                  ],
                  onChanged: (v) => setD(() => action = v ?? DisciplinaryAction.verbalWarning),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Parent Phone Number',
                    hintText: 'e.g. +237 670000000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: notifyParent,
                  title: const Text('Send SMS Alert to Parent immediately'),
                  onChanged: (v) => setD(() => notifyParent = v ?? false),
                ),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (studentCtrl.text.trim().isEmpty || infractionCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Log Incident'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && studentCtrl.text.trim().isNotEmpty) {
      final record = DisciplinaryRecord(
        id: 'disc_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: _schoolId,
        studentId: 'std_${studentCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
        studentName: studentCtrl.text.trim(),
        classLevel: classLevel,
        incidentDate: incidentDate,
        infraction: infractionCtrl.text.trim(),
        severity: severity,
        actionTaken: action,
        parentContact: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
        parentNotified: notifyParent,
        resolved: false,
        reportedBy: widget.user.name,
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      final res = await _repo.addRecord(record);
      if (res is Success) {
        if (notifyParent && phoneCtrl.text.trim().isNotEmpty) {
          final msg = SmsService.instance.composeDisciplinaryMessage(
            studentName: record.studentName,
            infraction: record.infraction,
            actionTaken: record.actionTaken.label,
            schoolName: widget.user.schoolName,
          );
          await SmsService.instance.sendSms(recipientPhone: phoneCtrl.text.trim(), message: msg);
        }
        if (mounted) showToast(context, 'Disciplinary record logged successfully.');
        _load();
      } else {
        if (mounted) showToast(context, 'Failed to log record: ${(res as Failure).message}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Disciplinary Records',
      currentDestination: AppNavDestination.schoolConnect,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: ac.surf, border: Border(bottom: BorderSide(color: ac.bdr))),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedClass,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Class',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Classes')),
                      for (final c in _classes) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedClass = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _addIncidentDialog,
                  icon: const Icon(Icons.add_alert_rounded, size: 16),
                  label: const Text('Log Incident'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 48, color: ac.muted),
                            const SizedBox(height: 12),
                            Text('No disciplinary incidents recorded',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: ac.txt)),
                            const SizedBox(height: 4),
                            Text('All students currently have good conduct standing.',
                                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        itemBuilder: (context, i) {
                          final r = _records[i];
                          Color badgeColor;
                          switch (r.severity) {
                            case DisciplinarySeverity.severe:
                              badgeColor = ac.red;
                              break;
                            case DisciplinarySeverity.moderate:
                              badgeColor = const Color(0xFFF59E0B);
                              break;
                            case DisciplinarySeverity.minor:
                              badgeColor = ac.primary;
                              break;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ac.surf,
                              borderRadius: BorderRadius.circular(Rad.md),
                              border: Border.all(color: ac.bdr),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            r.studentName,
                                            style: GoogleFonts.inter(
                                                fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: ac.surf2, borderRadius: BorderRadius.circular(4)),
                                            child: Text(r.classLevel,
                                                style: GoogleFonts.inter(
                                                    fontSize: 11, fontWeight: FontWeight.w600, color: ac.txt2)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        r.severity.name.toUpperCase(),
                                        style: GoogleFonts.inter(
                                            fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(r.infraction,
                                    style: GoogleFonts.inter(fontSize: 13.5, color: ac.txt, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.gavel_rounded, size: 14, color: ac.muted),
                                    const SizedBox(width: 4),
                                    Text('Action: ${r.actionTaken.label}',
                                        style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
                                    const SizedBox(width: 14),
                                    Icon(Icons.calendar_today_rounded, size: 13, color: ac.muted),
                                    const SizedBox(width: 4),
                                    Text(DateFormat('dd MMM yyyy').format(r.incidentDate),
                                        style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          r.parentNotified ? Icons.sms_rounded : Icons.sms_failed_outlined,
                                          size: 14,
                                          color: r.parentNotified ? ac.grn : ac.muted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          r.parentNotified ? 'Parent Notified via SMS' : 'Parent Not Notified',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            color: r.parentNotified ? ac.grn : ac.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await _repo.toggleResolved(_schoolId, r.id, !r.resolved);
                                        _load();
                                      },
                                      icon: Icon(
                                        r.resolved ? Icons.check_circle_rounded : Icons.pending_outlined,
                                        size: 16,
                                        color: r.resolved ? ac.grn : const Color(0xFFF59E0B),
                                      ),
                                      label: Text(
                                        r.resolved ? 'Resolved' : 'Mark Resolved',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: r.resolved ? ac.grn : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
