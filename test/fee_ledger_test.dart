import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/models/fee_ledger_entry.dart';
import 'package:academia_app/repositories/fee_repository.dart';

FeeLedgerEntry _e(String sid, String name, FeeEntryType t, double amt) => FeeLedgerEntry(
      id: '',
      schoolId: 's',
      studentId: sid,
      studentName: name,
      type: t,
      amount: amt,
      entryDate: DateTime(2026, 10, 14),
    );

void main() {
  group('Fee ledger balances (record-only)', () {
    test('signedAmount: charge adds, payment subtracts', () {
      expect(_e('a', 'A', FeeEntryType.charge, 100).signedAmount, 100);
      expect(_e('a', 'A', FeeEntryType.payment, 40).signedAmount, -40);
    });

    test('outstanding = charges - payments per student', () {
      final entries = [
        _e('a', 'Ada', FeeEntryType.charge, 50000),
        _e('a', 'Ada', FeeEntryType.payment, 20000),
        _e('a', 'Ada', FeeEntryType.payment, 10000),
        _e('b', 'Ben', FeeEntryType.charge, 50000),
      ];
      final balances = {for (final b in FeeRepository.balancesFrom(entries)) b.studentId: b};
      expect(balances['a']!.charged, 50000);
      expect(balances['a']!.paid, 30000);
      expect(balances['a']!.outstanding, 20000);
      expect(balances['a']!.settled, isFalse);
      expect(balances['b']!.outstanding, 50000);
    });

    test('fully paid student is settled', () {
      final entries = [
        _e('c', 'Cid', FeeEntryType.charge, 40000),
        _e('c', 'Cid', FeeEntryType.payment, 40000),
      ];
      final b = FeeRepository.balancesFrom(entries).single;
      expect(b.outstanding, 0);
      expect(b.settled, isTrue);
    });

    test('balances are sorted by student name', () {
      final entries = [
        _e('z', 'Zoe', FeeEntryType.charge, 1),
        _e('a', 'Ada', FeeEntryType.charge, 1),
      ];
      final order = FeeRepository.balancesFrom(entries).map((b) => b.studentName).toList();
      expect(order, ['Ada', 'Zoe']);
    });

    test('toMap omits empty id so the DB assigns one; round-trips fields', () {
      final e = _e('a', 'Ada', FeeEntryType.payment, 2500);
      expect(e.toMap().containsKey('id'), isFalse);
      final back = FeeLedgerEntry.fromMap({
        ...e.toMap(),
        'id': 'srv1',
        'entry_type': 'payment',
      });
      expect(back.id, 'srv1');
      expect(back.type, FeeEntryType.payment);
      expect(back.amount, 2500);
    });
  });
}
