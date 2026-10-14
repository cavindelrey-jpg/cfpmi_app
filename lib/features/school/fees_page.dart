// lib/features/school/fees_page.dart
// Record-only school fees. Staff pick a class, see each student's balance
// (charged vs recorded payments), open a student to view their ledger and
// RECORD a charge or a payment (sourced from a bank statement / slip).
// The app never processes money — it only keeps the record.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/fee_ledger_entry.dart';
import '../../models/student_record.dart';
import '../../repositories/fee_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../theme/app_colors.dart';
import 'widgets/management_scaffold.dart';

class FeesPage extends StatefulWidget {
  final AppUser user;
  const FeesPage({super.key, required this.user});

  @override
  State<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends State<FeesPage> {
  AppColors get ac => AppColors.of(context);
  String get _schoolId => widget.user.schoolId ?? '';

  final _repo = FeeRepository.instance;
  final _roster = StudentRosterRepository.instance;

  List<String> _classes = [];
  String? _class;
  List<StudentRecord> _students = [];
  Map<String, StudentFeeBalance> _balances = {};
  bool _loading = true;

  bool get _canManage =>
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
    final classes = <String>{for (final s in all) if (s.classLevel.isNotEmpty) s.classLevel}.toList()..sort();
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
    final ledgerRes = await _repo.getForClass(_schoolId, _class!);
    final students = rosterRes is Success<List<StudentRecord>> ? rosterRes.value : <StudentRecord>[];
    final entries = ledgerRes is Success<List<FeeLedgerEntry>> ? ledgerRes.value : <FeeLedgerEntry>[];
    if (!mounted) return;
    setState(() {
      _students = students;
      _balances = {for (final b in FeeRepository.balancesFrom(entries)) b.studentId: b};
      _loading = false;
    });
  }

  String _money(double v) => v
      .toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fees')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('You do not have permission to manage fees.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(color: ac.txt2)),
          ),
        ),
      );
    }
    return ManagementScaffold(
      title: 'Fees (record only)',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ac.bluBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: ac.blu),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Records only — no payments go through the app. Enter charges and '
                    'payments from the bank statement / slip.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_class == null || _students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('No students in this class yet. Add them to the roster first.',
              textAlign: TextAlign.center, style: GoogleFonts.inter(color: ac.txt2)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final s = _students[i];
        final b = _balances[s.id];
        final outstanding = b?.outstanding ?? 0;
        final hasCharge = (b?.charged ?? 0) > 0;
        final color = !hasCharge ? ac.muted : (outstanding <= 0 ? ac.grn : ac.red);
        final statusLabel = !hasCharge ? 'No charges' : (outstanding <= 0 ? 'Settled' : 'Owes ${_money(outstanding)}');
        return InkWell(
          onTap: () => _openStudent(s),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                      if (b != null)
                        Text('Charged ${_money(b.charged)} · Paid ${_money(b.paid)}',
                            style: GoogleFonts.inter(fontSize: 11, color: ac.txt2)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(statusLabel,
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
                ),
                Icon(Icons.chevron_right_rounded, color: ac.muted, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStudent(StudentRecord s) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _StudentFeeSheet(user: widget.user, student: s, schoolId: _schoolId),
    );
    await _load(); // refresh balances after any new entries
  }
}

class _StudentFeeSheet extends StatefulWidget {
  final AppUser user;
  final StudentRecord student;
  final String schoolId;
  const _StudentFeeSheet({required this.user, required this.student, required this.schoolId});

  @override
  State<_StudentFeeSheet> createState() => _StudentFeeSheetState();
}

class _StudentFeeSheetState extends State<_StudentFeeSheet> {
  AppColors get ac => AppColors.of(context);
  final _repo = FeeRepository.instance;
  List<FeeLedgerEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _repo.getForStudent(widget.student.id);
    if (!mounted) return;
    setState(() {
      _entries = res is Success<List<FeeLedgerEntry>> ? res.value : [];
      _loading = false;
    });
  }

  double get _outstanding =>
      _entries.fold(0.0, (sum, e) => sum + e.signedAmount);

  String _money(double v) => v
      .toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ac.bdr, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.student.name,
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: ac.txt)),
                        Text('Outstanding: ${_money(_outstanding)}',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _outstanding <= 0 ? ac.grn : ac.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addEntry(FeeEntryType.charge),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Record charge'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _addEntry(FeeEntryType.payment),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Record payment'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? Center(
                          child: Text('No fee records yet.',
                              style: GoogleFonts.inter(color: ac.txt2)))
                      : ListView.separated(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final isCharge = e.type == FeeEntryType.charge;
                            final color = isCharge ? ac.red : ac.grn;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: ac.surf,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ac.bdr),
                              ),
                              child: Row(
                                children: [
                                  Icon(isCharge ? Icons.request_quote_outlined : Icons.payments_outlined,
                                      color: color, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${e.type.label} · ${_money(e.amount)}',
                                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt)),
                                        Text(
                                          [
                                            FeeLedgerEntry.dateKey(e.entryDate),
                                            if (e.reference.isNotEmpty) 'Ref: ${e.reference}',
                                            if ((e.note ?? '').isNotEmpty) e.note!,
                                          ].join(' · '),
                                          style: GoogleFonts.inter(fontSize: 11, color: ac.txt2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEntry(FeeEntryType type) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _FeeEntryDialog(user: widget.user, student: widget.student, schoolId: widget.schoolId, type: type),
    );
    if (added == true) {
      setState(() => _loading = true);
      await _load();
    }
  }
}

class _FeeEntryDialog extends StatefulWidget {
  final AppUser user;
  final StudentRecord student;
  final String schoolId;
  final FeeEntryType type;
  const _FeeEntryDialog({required this.user, required this.student, required this.schoolId, required this.type});

  @override
  State<_FeeEntryDialog> createState() => _FeeEntryDialogState();
}

class _FeeEntryDialogState extends State<_FeeEntryDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    setState(() => _saving = true);
    final entry = FeeLedgerEntry(
      id: '',
      schoolId: widget.schoolId,
      studentId: widget.student.id,
      studentName: widget.student.name,
      classLevel: widget.student.classLevel,
      type: widget.type,
      amount: amount,
      entryDate: _date,
      reference: _reference.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      recordedBy: widget.user.name,
    );
    final res = await FeeRepository.instance.addEntry(entry);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res is Success<void>) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((res as Failure<void>).friendlyMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPayment = widget.type == FeeEntryType.payment;
    return AlertDialog(
      title: Text(isPayment ? 'Record a payment' : 'Record a charge'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                labelText: isPayment ? 'Bank statement / slip reference' : 'Invoice / reference (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Date: ${FeeLedgerEntry.dateKey(_date)}')),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
