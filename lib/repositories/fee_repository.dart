// lib/repositories/fee_repository.dart
// School fees as a record-only ledger. Backed by public.fee_ledger (see
// supabase/migrations/20261014130000_fee_ledger.sql). Staff record charges
// and payments (sourced from the bank statement); balances are derived.
// The app performs NO payment processing. Same Supabase + Result idiom as
// AttendanceRepository.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../models/fee_ledger_entry.dart';

class FeeRepository {
  FeeRepository._();
  static final FeeRepository instance = FeeRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _table => _db?.from('fee_ledger');

  /// Record one ledger line (a charge or a recorded payment).
  Future<Result<void>> addEntry(FeeLedgerEntry entry) async {
    final table = _table;
    if (table == null) return const Failure('Fees are offline right now.');
    try {
      await table.insert(entry.toMap());
      return const Success(null);
    } catch (e) {
      return Failure('Could not save the fee entry.', e);
    }
  }

  Future<Result<void>> deleteEntry(String id) async {
    final table = _table;
    if (table == null) return const Failure('Fees are offline right now.');
    try {
      await table.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Could not delete the fee entry.', e);
    }
  }

  /// Every ledger line for one student (newest first).
  Future<Result<List<FeeLedgerEntry>>> getForStudent(String studentId) async {
    if (studentId.isEmpty) return const Success([]);
    final table = _table;
    if (table == null) return const Failure('Fees are offline right now.');
    try {
      final rows = await table.select().eq('student_id', studentId).order('entry_date', ascending: false);
      return Success((rows as List).map((r) => FeeLedgerEntry.fromMap(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Could not load the fee ledger.', e);
    }
  }

  /// All ledger lines for a class (optionally one academic year/term).
  Future<Result<List<FeeLedgerEntry>>> getForClass(
    String schoolId,
    String classLevel, {
    String? academicYear,
    String? term,
  }) async {
    if (schoolId.isEmpty || classLevel.isEmpty) return const Success([]);
    final table = _table;
    if (table == null) return const Failure('Fees are offline right now.');
    try {
      var q = table.select().eq('school_id', schoolId).eq('class_level', classLevel);
      if (academicYear != null && academicYear.isNotEmpty) q = q.eq('academic_year', academicYear);
      if (term != null && term.isNotEmpty) q = q.eq('term', term);
      final rows = await q.order('entry_date', ascending: false);
      return Success((rows as List).map((r) => FeeLedgerEntry.fromMap(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Could not load class fees.', e);
    }
  }

  /// Roll a flat ledger up into per-student balances (pure, testable).
  static List<StudentFeeBalance> balancesFrom(List<FeeLedgerEntry> entries) {
    final charged = <String, double>{};
    final paid = <String, double>{};
    final names = <String, String>{};
    for (final e in entries) {
      names[e.studentId] = e.studentName;
      if (e.type == FeeEntryType.charge) {
        charged[e.studentId] = (charged[e.studentId] ?? 0) + e.amount;
      } else {
        paid[e.studentId] = (paid[e.studentId] ?? 0) + e.amount;
      }
    }
    final ids = {...charged.keys, ...paid.keys}.toList()
      ..sort((a, b) => (names[a] ?? '').compareTo(names[b] ?? ''));
    return [
      for (final id in ids)
        StudentFeeBalance(
          studentId: id,
          studentName: names[id] ?? '',
          charged: charged[id] ?? 0,
          paid: paid[id] ?? 0,
        ),
    ];
  }
}
