// lib/models/disciplinary_record.dart
// Student disciplinary records management model.

enum DisciplinarySeverity { minor, moderate, severe }

enum DisciplinaryAction {
  verbalWarning,
  writtenWarning,
  detention,
  parentConference,
  suspension,
  expulsion;

  String get label {
    switch (this) {
      case DisciplinaryAction.verbalWarning:
        return 'Verbal Warning';
      case DisciplinaryAction.writtenWarning:
        return 'Written Warning';
      case DisciplinaryAction.detention:
        return 'Detention';
      case DisciplinaryAction.parentConference:
        return 'Parent Conference';
      case DisciplinaryAction.suspension:
        return 'Suspension';
      case DisciplinaryAction.expulsion:
        return 'Expulsion';
    }
  }

  static DisciplinaryAction fromString(String val) {
    for (final a in DisciplinaryAction.values) {
      if (a.name.toLowerCase() == val.toLowerCase()) return a;
    }
    return DisciplinaryAction.verbalWarning;
  }
}

class DisciplinaryRecord {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String classLevel;
  final DateTime incidentDate;
  final String infraction;
  final DisciplinarySeverity severity;
  final DisciplinaryAction actionTaken;
  final String? parentContact;
  final bool parentNotified;
  final bool resolved;
  final String? reportedBy;
  final String? notes;

  const DisciplinaryRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.classLevel,
    required this.incidentDate,
    required this.infraction,
    required this.severity,
    required this.actionTaken,
    this.parentContact,
    this.parentNotified = false,
    this.resolved = false,
    this.reportedBy,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'student_id': studentId,
        'student_name': studentName,
        'class_level': classLevel,
        'incident_date': incidentDate.toIso8601String(),
        'infraction': infraction,
        'severity': severity.name,
        'action_taken': actionTaken.name,
        'parent_contact': parentContact,
        'parent_notified': parentNotified,
        'resolved': resolved,
        'reported_by': reportedBy,
        'notes': notes,
      };

  factory DisciplinaryRecord.fromMap(Map<String, dynamic> m) =>
      DisciplinaryRecord(
        id: m['id']?.toString() ?? '',
        schoolId: m['school_id']?.toString() ?? '',
        studentId: m['student_id']?.toString() ?? '',
        studentName: m['student_name']?.toString() ?? 'Student',
        classLevel: m['class_level']?.toString() ?? '',
        incidentDate: m['incident_date'] != null
            ? DateTime.tryParse(m['incident_date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        infraction: m['infraction']?.toString() ?? '',
        severity: DisciplinarySeverity.values.firstWhere(
          (s) => s.name.toLowerCase() == (m['severity']?.toString().toLowerCase() ?? ''),
          orElse: () => DisciplinarySeverity.minor,
        ),
        actionTaken: DisciplinaryAction.fromString(m['action_taken']?.toString() ?? ''),
        parentContact: m['parent_contact']?.toString(),
        parentNotified: m['parent_notified'] == true,
        resolved: m['resolved'] == true,
        reportedBy: m['reported_by']?.toString(),
        notes: m['notes']?.toString(),
      );
}
