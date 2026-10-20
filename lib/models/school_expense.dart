// lib/models/school_expense.dart
// Non-payroll operational expense tracking for school administration.
// Strictly tracks general school expenses (utilities, lab supplies, maintenance,
// events, equipment). Excludes teacher payroll, staff salary, and salary vouchers.

enum ExpenseCategory {
  utilities,
  maintenance,
  supplies,
  laboratory,
  examination,
  transportation,
  events,
  miscellaneous;

  String get label {
    switch (this) {
      case ExpenseCategory.utilities:
        return 'Utilities (Water, Power, Net)';
      case ExpenseCategory.maintenance:
        return 'Facility Maintenance & Repairs';
      case ExpenseCategory.supplies:
        return 'Office & Classroom Supplies';
      case ExpenseCategory.laboratory:
        return 'Lab Equipment & Materials';
      case ExpenseCategory.examination:
        return 'Examination Printing & Materials';
      case ExpenseCategory.transportation:
        return 'School Transportation & Fuel';
      case ExpenseCategory.events:
        return 'Academic & Sports Events';
      case ExpenseCategory.miscellaneous:
        return 'Miscellaneous Expenses';
    }
  }

  static ExpenseCategory fromString(String val) {
    for (final c in ExpenseCategory.values) {
      if (c.name.toLowerCase() == val.toLowerCase()) return c;
    }
    return ExpenseCategory.miscellaneous;
  }
}

class SchoolExpense {
  final String id;
  final String schoolId;
  final ExpenseCategory category;
  final String title;
  final double amount;
  final DateTime date;
  final String? receiptRef;
  final String? recordedBy;
  final String? notes;

  const SchoolExpense({
    required this.id,
    required this.schoolId,
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.receiptRef,
    this.recordedBy,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'category': category.name,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'receipt_ref': receiptRef,
        'recorded_by': recordedBy,
        'notes': notes,
      };

  factory SchoolExpense.fromMap(Map<String, dynamic> m) => SchoolExpense(
        id: m['id']?.toString() ?? '',
        schoolId: m['school_id']?.toString() ?? '',
        category: ExpenseCategory.fromString(m['category']?.toString() ?? ''),
        title: m['title']?.toString() ?? 'Expense',
        amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0,
        date: m['date'] != null
            ? DateTime.tryParse(m['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        receiptRef: m['receipt_ref']?.toString(),
        recordedBy: m['recorded_by']?.toString(),
        notes: m['notes']?.toString(),
      );
}
