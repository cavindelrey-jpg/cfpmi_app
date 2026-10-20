// lib/repositories/expense_repository.dart
// Non-payroll operational expense tracking for school administration.
// Strictly tracks general school expenses (utilities, supplies, maintenance,
// events, equipment). Excludes teacher payroll, staff salary, and salary vouchers.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/offline_cache.dart';
import '../core/result.dart';
import '../models/school_expense.dart';
import 'student_roster_repository.dart';

class ExpenseRepository {
  ExpenseRepository._();
  static final ExpenseRepository instance = ExpenseRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<Result<List<SchoolExpense>>> getExpenses(String schoolId) async {
    final resolvedSchoolId = StudentRosterRepository.resolveSchoolId(schoolId);
    final cacheKey = 'expenses_$resolvedSchoolId';

    try {
      final cached = await OfflineCache.instance.get<List<SchoolExpense>>(
        cacheKey,
        (json) => OfflineCache.listFromJson(json, (j) => SchoolExpense.fromMap(j)),
      );

      final list = await OfflineCache.instance.fetch<List<SchoolExpense>>(
        cacheKey,
        () async {
          final db = _db;
          if (db != null) {
            try {
              final rows = await db
                  .from('school_expenses')
                  .select()
                  .eq('school_id', resolvedSchoolId)
                  .order('date', ascending: false);
              return (rows as List)
                  .map((r) => SchoolExpense.fromMap(r as Map<String, dynamic>))
                  .toList();
            } catch (_) {}
          }
          return cached ?? <SchoolExpense>[];
        },
        toJson: (items) => OfflineCache.listToJson(items, (e) => e.toMap()),
        fromJson: (json) => OfflineCache.listFromJson(json, (j) => SchoolExpense.fromMap(j)),
      );
      return Success(list);
    } catch (e) {
      return Failure('Could not load school expenses', e);
    }
  }

  Future<Result<void>> addExpense(SchoolExpense expense) async {
    final resolvedSchoolId = StudentRosterRepository.resolveSchoolId(expense.schoolId);
    final normalized = SchoolExpense(
      id: expense.id,
      schoolId: resolvedSchoolId,
      category: expense.category,
      title: expense.title,
      amount: expense.amount,
      date: expense.date,
      receiptRef: expense.receiptRef,
      recordedBy: expense.recordedBy,
      notes: expense.notes,
    );

    // 1. Immediately cache locally
    final cacheKey = 'expenses_$resolvedSchoolId';
    final existing = await OfflineCache.instance.get<List<SchoolExpense>>(
      cacheKey,
      (json) => OfflineCache.listFromJson(json, (j) => SchoolExpense.fromMap(j)),
    ) ?? [];
    final next = [normalized, ...existing.where((e) => e.id != normalized.id)];
    await OfflineCache.instance.put(
      cacheKey,
      OfflineCache.listToJson(next, (e) => e.toMap()),
    );

    // 2. Try Supabase insert
    final db = _db;
    if (db != null) {
      try {
        await db.from('school_expenses').insert(normalized.toMap());
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<Result<void>> deleteExpense(String schoolId, String expenseId) async {
    final resolvedSchoolId = StudentRosterRepository.resolveSchoolId(schoolId);
    final cacheKey = 'expenses_$resolvedSchoolId';
    final existing = await OfflineCache.instance.get<List<SchoolExpense>>(
      cacheKey,
      (json) => OfflineCache.listFromJson(json, (j) => SchoolExpense.fromMap(j)),
    ) ?? [];
    final next = existing.where((e) => e.id != expenseId).toList();
    await OfflineCache.instance.put(
      cacheKey,
      OfflineCache.listToJson(next, (e) => e.toMap()),
    );

    final db = _db;
    if (db != null) {
      try {
        await db.from('school_expenses').delete().eq('id', expenseId);
      } catch (_) {}
    }

    return const Success(null);
  }
}
