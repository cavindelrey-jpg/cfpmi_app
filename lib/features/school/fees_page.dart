// lib/features/school/fees_page.dart
// Unified School Fees & Ledger Workspace inside ApplicationShell:
// - Staff / Admins: Pick a class, view each student's balance (charged vs
//   recorded payments), open a student to view their ledger and record a
//   charge or payment (FeeRepository).
// - Students: Real read-only fee ledger and balance statement from
//   FeeRepository.instance.getForStudent(user.id).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/fee_ledger_entry.dart';
import '../../models/school_expense.dart';
import '../../models/student_record.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/fee_repository.dart';
import '../../repositories/school_class_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/application_shell.dart';
import '../../widgets/widgets.dart';

class FeesPage extends StatefulWidget {
  final AppUser user;
  const FeesPage({super.key, required this.user});

  @override
  State<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends State<FeesPage> {
  AppColors get ac => AppColors.of(context);
  String get _schoolId => widget.user.effectiveSchoolId;

  final _repo = FeeRepository.instance;
  final _roster = StudentRosterRepository.instance;

  List<String> _classes = [];
  String? _class;
  List<StudentRecord> _students = [];
  Map<String, StudentFeeBalance> _balances = {};
  List<SchoolExpense> _expenses = [];
  int _selectedTab = 0; // 0 = Tuition & Fees, 1 = Operating Expenses
  bool _loading = true;

  bool get _canManage =>
      widget.user.canRecordAnyMarks ||
      (widget.user.isSchoolMember &&
          !widget.user.isStudent &&
          !widget.user.isParent);

  @override
  void initState() {
    super.initState();
    if (_canManage) {
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
    setState(() => _loading = true);
    final expenseRes = await ExpenseRepository.instance.getExpenses(_schoolId);
    final expenses = expenseRes is Success<List<SchoolExpense>>
        ? expenseRes.value
        : <SchoolExpense>[];

    if (_class == null) {
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _loading = false;
      });
      return;
    }
    final rosterRes = await _roster.getStudents(_schoolId, classLevel: _class);
    final ledgerRes = await _repo.getForClass(_schoolId, _class!);
    final students = rosterRes is Success<List<StudentRecord>>
        ? rosterRes.value
        : <StudentRecord>[];
    final entries = ledgerRes is Success<List<FeeLedgerEntry>>
        ? ledgerRes.value
        : <FeeLedgerEntry>[];
    if (!mounted) return;
    setState(() {
      _students = students;
      _balances = {
        for (final b in FeeRepository.balancesFrom(entries)) b.studentId: b,
      };
      _expenses = expenses;
      _loading = false;
    });
  }

  Future<void> _promptSetFees() async {
    final titleCtrl = TextEditingController(text: 'Tuition Fee');
    final amountCtrl = TextEditingController(text: '50000');
    final yearCtrl = TextEditingController(text: '2025/2026');
    String term = 'Term 1';
    String targetClass = _class ?? (_classes.isNotEmpty ? _classes.first : 'Form 1');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Set Fees & Tuition Charges',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: targetClass,
                  decoration: const InputDecoration(labelText: 'Target Class', border: OutlineInputBorder()),
                  items: [
                    for (final c in _classes) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => targetClass = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(labelText: 'Academic Year', hintText: '2025/2026', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: term,
                  decoration: const InputDecoration(labelText: 'Term / Scope', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Term 1', child: Text('Term 1')),
                    DropdownMenuItem(value: 'Term 2', child: Text('Term 2')),
                    DropdownMenuItem(value: 'Term 3', child: Text('Term 3')),
                    DropdownMenuItem(value: 'Annual', child: Text('Annual / Whole Year')),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => term = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Fee Title *', hintText: 'e.g. Tuition Fee, Exam Fee', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (XAF) *', hintText: 'e.g. 50000', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (titleCtrl.text.trim().isEmpty || amt <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Apply Fee to Class'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final title = titleCtrl.text.trim();
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      final year = yearCtrl.text.trim().isNotEmpty ? yearCtrl.text.trim() : '2025/2026';

      final rosterRes = await _roster.getStudents(_schoolId, classLevel: targetClass);
      final students = rosterRes is Success<List<StudentRecord>> ? rosterRes.value : <StudentRecord>[];

      if (students.isEmpty) {
        final entry = FeeLedgerEntry(
          id: 'fee_${DateTime.now().millisecondsSinceEpoch}',
          schoolId: _schoolId,
          studentId: 'class_baseline_${targetClass.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
          studentName: 'Class Baseline ($targetClass)',
          classLevel: targetClass,
          academicYear: year,
          term: term,
          type: FeeEntryType.charge,
          amount: amount,
          entryDate: DateTime.now(),
          reference: 'FEE-SET-$term-$year',
          note: title,
          recordedBy: widget.user.name,
        );
        await _repo.addEntry(entry);
      } else {
        int count = 0;
        for (final s in students) {
          final entry = FeeLedgerEntry(
            id: 'fee_${DateTime.now().millisecondsSinceEpoch}_${count++}',
            schoolId: _schoolId,
            studentId: s.id,
            studentName: s.name,
            classLevel: targetClass,
            academicYear: year,
            term: term,
            type: FeeEntryType.charge,
            amount: amount,
            entryDate: DateTime.now(),
            reference: 'FEE-CONFIG-$term-$year',
            note: title,
            recordedBy: widget.user.name,
          );
          await _repo.addEntry(entry);
        }
      }

      if (mounted) showToast(context, 'Set fee "$title" ($amount XAF) for $targetClass.');
      await _load();
    }
  }

  Future<void> _promptAddExpense() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final receiptCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    ExpenseCategory category = ExpenseCategory.supplies;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Record Operating Expense',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ExpenseCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Expense Category *', border: OutlineInputBorder()),
                  items: [
                    for (final c in ExpenseCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => category = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Description / Item *', hintText: 'e.g. Science Lab Reagents', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (XAF) *', hintText: 'e.g. 75000', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: receiptCtrl,
                  decoration: const InputDecoration(labelText: 'Receipt / Invoice Ref', hintText: 'e.g. REC-88219', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (titleCtrl.text.trim().isEmpty || amt <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final title = titleCtrl.text.trim();
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      final expense = SchoolExpense(
        id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: _schoolId,
        category: category,
        title: title,
        amount: amount,
        date: DateTime.now(),
        receiptRef: receiptCtrl.text.trim().isNotEmpty ? receiptCtrl.text.trim() : null,
        recordedBy: widget.user.name,
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      final res = await ExpenseRepository.instance.addExpense(expense);
      if (res is Success) {
        if (mounted) showToast(context, 'Saved expense: $title ($amount XAF)');
        await _load();
      } else {
        if (mounted) showToast(context, 'Could not save expense: ${(res as Failure).message}', isError: true);
      }
    }
  }

  String _money(double v) => v
      .toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    if (!_canManage) {
      return ApplicationShell(
        user: widget.user,
        currentTitle: 'Fees & Ledger',
        subtitle: 'Personal tuition statement and recorded payments',
        currentDestination: AppNavDestination.fees,
        child: _StudentFeesView(user: widget.user),
      );
    }

    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Fees & Expenses',
      subtitle: 'Manage student tuition charges and school operational expenses',
      currentDestination: AppNavDestination.fees,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Tuition & Fees'),
                        icon: Icon(Icons.receipt_long_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Operating Expenses'),
                        icon: Icon(Icons.account_balance_wallet_outlined, size: 16),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (s) => setState(() => _selectedTab = s.first),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedTab == 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _class,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in _classes) DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) {
                        setState(() => _class = v);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _promptSetFees,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Set Fees'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ac.bluBg,
                borderRadius: BorderRadius.circular(10),
              ),
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
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Operational Expenses (Excl. Payroll)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt),
                  ),
                  ElevatedButton.icon(
                    onPressed: _promptAddExpense,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Record Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _expensesList()),
          ],
        ],
      ),
    );
  }

  Widget _expensesList() {
    if (_loading) return const SkeletonList();
    if (_expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 48, color: ac.muted),
              const SizedBox(height: 12),
              Text('No operating expenses recorded yet',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: ac.txt)),
              const SizedBox(height: 4),
              Text('Record general utility, supply, laboratory, and maintenance expenses.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
            ],
          ),
        ),
      );
    }

    final totalSpent = _expenses.fold<double>(0.0, (acc, e) => acc + e.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Operating Expenditure',
                      style: GoogleFonts.inter(fontSize: 12, color: ac.txt2, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('${_money(totalSpent)} XAF',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: ac.primary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(8)),
                child: Text('${_expenses.length} Entries',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt)),
              ),
            ],
          ),
        ),
        for (final exp in _expenses)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ac.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_rounded, size: 20, color: ac.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exp.title,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
                      const SizedBox(height: 2),
                      Text('${exp.category.label}${exp.receiptRef != null ? " • Ref: ${exp.receiptRef}" : ""}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_money(exp.amount)} XAF',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
                    Text(
                      '${exp.date.day}/${exp.date.month}/${exp.date.year}',
                      style: GoogleFonts.inter(fontSize: 11, color: ac.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _list() {
    if (_loading) return const SkeletonList();
    if (_class == null || _students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'No students in this class yet. Add them to the school roster first.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: ac.txt2),
          ),
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
        final color =
            !hasCharge ? ac.muted : (outstanding <= 0 ? ac.grn : ac.red);
        final statusLabel = !hasCharge
            ? 'No charges'
            : (outstanding <= 0
                ? 'Settled'
                : 'Owes ${_money(outstanding)}');
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
                      if (b != null)
                        Text(
                          'Charged ${_money(b.charged)} · Paid ${_money(b.paid)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: ac.txt2,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _StudentFeeSheet(
        user: widget.user,
        student: s,
        schoolId: _schoolId,
      ),
    );
    await _load();
  }
}

class _StudentFeesView extends StatefulWidget {
  final AppUser user;
  const _StudentFeesView({required this.user});

  @override
  State<_StudentFeesView> createState() => _StudentFeesViewState();
}

class _StudentFeesViewState extends State<_StudentFeesView> {
  AppColors get ac => AppColors.of(context);
  List<FeeLedgerEntry> _entries = [];
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
    final res = await FeeRepository.instance.getForStudent(widget.user.id);
    if (!mounted) return;
    setState(() {
      _entries = res is Success<List<FeeLedgerEntry>> ? res.value : [];
      _loading = false;
    });
  }

  double get _outstanding =>
      _entries.fold(0.0, (s, e) => s + e.signedAmount);

  String _money(double v) => v
      .toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList();
    if (widget.user.isGuest || widget.user.id.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: ac.muted,
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to view your fee statement',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect your student account to see recorded tuition charges and payments.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: ac.muted,
              ),
              const SizedBox(height: 12),
              Text(
                'No fee records yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your fee charges and payments will appear here once recorded by your school.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
              ),
            ],
          ),
        ),
      );
    }

    final owes = _outstanding > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (owes ? ac.red : ac.grn).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (owes ? ac.red : ac.grn).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                owes ? 'Outstanding Balance' : 'Account Balance',
                style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
              ),
              const SizedBox(height: 4),
              Text(
                _money(_outstanding),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: owes ? ac.red : ac.grn,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                owes
                    ? 'Please settle with the school bursary.'
                    : 'Your tuition account is up to date.',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'LEDGER HISTORY (${_entries.length})',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ac.txt2,
          ),
        ),
        const SizedBox(height: 10),
        for (final e in _entries)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ac.bdr),
            ),
            child: Row(
              children: [
                Icon(
                  e.type == FeeEntryType.charge
                      ? Icons.request_quote_outlined
                      : Icons.payments_outlined,
                  color: e.type == FeeEntryType.charge ? ac.red : ac.grn,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.type.label} · ${_money(e.amount)}',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: ac.txt,
                        ),
                      ),
                      Text(
                        [
                          FeeLedgerEntry.dateKey(e.entryDate),
                          if (e.reference.isNotEmpty) 'Ref: ${e.reference}',
                          if ((e.note ?? '').isNotEmpty) e.note!,
                        ].join(' · '),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: ac.txt2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StudentFeeSheet extends StatefulWidget {
  final AppUser user;
  final StudentRecord student;
  final String schoolId;
  const _StudentFeeSheet({
    required this.user,
    required this.student,
    required this.schoolId,
  });

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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ac.bdr,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.name,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: ac.txt,
                          ),
                        ),
                        Text(
                          'Outstanding: ${_money(_outstanding)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _outstanding <= 0 ? ac.grn : ac.red,
                          ),
                        ),
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
                          child: Text(
                            'No fee records yet.',
                            style: GoogleFonts.inter(color: ac.txt2),
                          ),
                        )
                      : ListView.separated(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final isCharge = e.type == FeeEntryType.charge;
                            final color = isCharge ? ac.red : ac.grn;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: ac.surf,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ac.bdr),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCharge
                                        ? Icons.request_quote_outlined
                                        : Icons.payments_outlined,
                                    color: color,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${e.type.label} · ${_money(e.amount)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: ac.txt,
                                          ),
                                        ),
                                        Text(
                                          [
                                            FeeLedgerEntry.dateKey(e.entryDate),
                                            if (e.reference.isNotEmpty)
                                              'Ref: ${e.reference}',
                                            if ((e.note ?? '').isNotEmpty)
                                              e.note!,
                                          ].join(' · '),
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
      builder: (_) => _FeeEntryDialog(
        user: widget.user,
        student: widget.student,
        schoolId: widget.schoolId,
        type: type,
      ),
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
  const _FeeEntryDialog({
    required this.user,
    required this.student,
    required this.schoolId,
    required this.type,
  });

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((res as Failure<void>).friendlyMessage)),
      );
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                labelText: isPayment
                    ? 'Bank statement / slip reference'
                    : 'Invoice / reference (optional)',
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
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
