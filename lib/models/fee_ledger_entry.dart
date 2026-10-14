// lib/models/fee_ledger_entry.dart
// One line in a student's fee ledger. The app RECORDS money that moved
// elsewhere (bank statement / slip) — it never processes payments.
// A 'charge' is a fee owed; a 'payment' is money received. Outstanding
// balance = sum(charge) - sum(payment). Backed by public.fee_ledger
// (see supabase/migrations/20261014130000_fee_ledger.sql).

enum FeeEntryType { charge, payment }

extension FeeEntryTypeX on FeeEntryType {
  String get wire => name; // charge|payment
  String get label => this == FeeEntryType.charge ? 'Charge' : 'Payment';

  static FeeEntryType fromWire(String? s) =>
      s == 'payment' ? FeeEntryType.payment : FeeEntryType.charge;
}

class FeeLedgerEntry {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String classLevel;
  final String academicYear;
  final String term;
  final FeeEntryType type;
  final double amount;
  final DateTime entryDate;

  /// Bank-statement line / slip / invoice number this entry mirrors.
  final String reference;
  final String? note;
  final String recordedBy;

  const FeeLedgerEntry({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    this.classLevel = '',
    this.academicYear = '',
    this.term = '',
    required this.type,
    required this.amount,
    required this.entryDate,
    this.reference = '',
    this.note,
    this.recordedBy = '',
  });

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Signed contribution to a balance: charges add, payments subtract.
  double get signedAmount => type == FeeEntryType.charge ? amount : -amount;

  factory FeeLedgerEntry.fromMap(Map<String, dynamic> m) {
    final raw = m['entry_date']?.toString();
    return FeeLedgerEntry(
      id: m['id']?.toString() ?? '',
      schoolId: m['school_id']?.toString() ?? '',
      studentId: m['student_id']?.toString() ?? '',
      studentName: m['student_name']?.toString() ?? '',
      classLevel: m['class_level']?.toString() ?? '',
      academicYear: m['academic_year']?.toString() ?? '',
      term: m['term']?.toString() ?? '',
      type: FeeEntryTypeX.fromWire(m['entry_type']?.toString()),
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      entryDate: raw != null ? (DateTime.tryParse(raw) ?? DateTime.now()) : DateTime.now(),
      reference: m['reference']?.toString() ?? '',
      note: m['note']?.toString(),
      recordedBy: m['recorded_by']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': id,
        'school_id': schoolId,
        'student_id': studentId,
        'student_name': studentName,
        'class_level': classLevel,
        'academic_year': academicYear,
        'term': term,
        'entry_type': type.wire,
        'amount': amount,
        'entry_date': dateKey(entryDate),
        'reference': reference,
        'note': note,
        'recorded_by': recordedBy,
      };
}

/// A student's rolled-up fee position for a class/term view.
class StudentFeeBalance {
  final String studentId;
  final String studentName;
  final double charged;
  final double paid;
  const StudentFeeBalance({
    required this.studentId,
    required this.studentName,
    required this.charged,
    required this.paid,
  });

  double get outstanding => charged - paid;
  bool get settled => outstanding <= 0 && charged > 0;
}
