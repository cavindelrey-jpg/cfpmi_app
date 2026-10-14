// lib/features/school/student_records_page.dart
// Student self-service, read-only: "My Attendance" + "My Fees". Keyed on the
// signed-in user's id (matches the attendance_records / fee_ledger RLS
// `student_id = auth.uid()`). Students can see but never modify these.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/attendance_record.dart';
import '../../models/fee_ledger_entry.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/fee_repository.dart';
import '../../theme/app_colors.dart';

class StudentRecordsPage extends StatelessWidget {
  final AppUser user;
  const StudentRecordsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(
          title: const Text('My Records'),
          bottom: TabBar(
            labelColor: ac.primary,
            unselectedLabelColor: ac.txt2,
            indicatorColor: ac.primary,
            tabs: const [
              Tab(text: 'Attendance', icon: Icon(Icons.fact_check_outlined)),
              Tab(text: 'Fees', icon: Icon(Icons.account_balance_wallet_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyAttendance(user: user),
            _MyFees(user: user),
          ],
        ),
      ),
    );
  }
}

class _MyAttendance extends StatefulWidget {
  final AppUser user;
  const _MyAttendance({required this.user});
  @override
  State<_MyAttendance> createState() => _MyAttendanceState();
}

class _MyAttendanceState extends State<_MyAttendance> {
  AppColors get ac => AppColors.of(context);
  List<AttendanceRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await AttendanceRepository.instance.getForStudent(widget.user.id);
    if (!mounted) return;
    setState(() {
      _records = res is Success<List<AttendanceRecord>> ? res.value : [];
      _loading = false;
    });
  }

  int _count(AttendanceStatus s) => _records.where((r) => r.status == s).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_records.isEmpty) {
      return _empty(ac, Icons.fact_check_outlined, 'No attendance recorded yet.',
          'Your teachers haven\'t marked any sessions for you so far.');
    }
    final total = _records.length;
    final present = _count(AttendanceStatus.present);
    final rate = total == 0 ? 0 : (present / total * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [ac.primary, ac.navy]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$rate%', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('Attendance rate', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
              const Spacer(),
              _miniStat('Present', _count(AttendanceStatus.present)),
              _miniStat('Absent', _count(AttendanceStatus.absent)),
              _miniStat('Late', _count(AttendanceStatus.late)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final r in _records) _attendanceRow(r),
      ],
    );
  }

  Widget _miniStat(String label, int n) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Column(
          children: [
            Text('$n', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AttendanceRecord.dateKey(r.sessionDate),
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
                Text(r.subject.isEmpty ? r.classLevel : '${r.classLevel} · ${r.subject}',
                    style: GoogleFonts.inter(fontSize: 11, color: ac.txt2)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(r.status.label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _MyFees extends StatefulWidget {
  final AppUser user;
  const _MyFees({required this.user});
  @override
  State<_MyFees> createState() => _MyFeesState();
}

class _MyFeesState extends State<_MyFees> {
  AppColors get ac => AppColors.of(context);
  List<FeeLedgerEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await FeeRepository.instance.getForStudent(widget.user.id);
    if (!mounted) return;
    setState(() {
      _entries = res is Success<List<FeeLedgerEntry>> ? res.value : [];
      _loading = false;
    });
  }

  double get _outstanding => _entries.fold(0.0, (s, e) => s + e.signedAmount);
  String _money(double v) => v
      .toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_entries.isEmpty) {
      return _empty(ac, Icons.account_balance_wallet_outlined, 'No fee records yet.',
          'Your fee charges and payments will appear here once recorded.');
    }
    final owes = _outstanding > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (owes ? ac.red : ac.grn).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: (owes ? ac.red : ac.grn).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(owes ? 'Outstanding balance' : 'Balance',
                  style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
              const SizedBox(height: 4),
              Text(_money(_outstanding),
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: owes ? ac.red : ac.grn)),
              Text(owes ? 'Please settle with the school bursary.' : 'You are up to date.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('History', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ac.txt)),
        const SizedBox(height: 8),
        for (final e in _entries) _feeRow(e),
      ],
    );
  }

  Widget _feeRow(FeeLedgerEntry e) {
    final isCharge = e.type == FeeEntryType.charge;
    final color = isCharge ? ac.red : ac.grn;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.bdr)),
      child: Row(
        children: [
          Icon(isCharge ? Icons.request_quote_outlined : Icons.payments_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.type.label} · ${_money(e.amount)}',
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: ac.txt)),
                Text([FeeLedgerEntry.dateKey(e.entryDate), if (e.reference.isNotEmpty) 'Ref: ${e.reference}'].join(' · '),
                    style: GoogleFonts.inter(fontSize: 11, color: ac.txt2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _empty(AppColors ac, IconData icon, String title, String subtitle) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: ac.muted),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2)),
          ],
        ),
      ),
    );
