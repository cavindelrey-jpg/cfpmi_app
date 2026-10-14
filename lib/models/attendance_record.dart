// lib/models/attendance_record.dart
// One student's attendance for a given class/date (and optional subject).
// Backed by public.attendance_records (see
// supabase/migrations/20261014120000_attendance_records.sql).

enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusX on AttendanceStatus {
  String get wire => name; // present|absent|late|excused
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.excused:
        return 'Excused';
    }
  }

  static AttendanceStatus fromWire(String? s) {
    switch (s) {
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'excused':
        return AttendanceStatus.excused;
      case 'present':
      default:
        return AttendanceStatus.present;
    }
  }
}

class AttendanceRecord {
  final String id;
  final String schoolId;
  final String classLevel;

  /// '' = whole-day / homeroom register; a value scopes it to one period.
  final String subject;
  final DateTime sessionDate;
  final String studentId;
  final String studentName;
  final AttendanceStatus status;
  final String? note;
  final String recordedBy;

  const AttendanceRecord({
    required this.id,
    required this.schoolId,
    required this.classLevel,
    this.subject = '',
    required this.sessionDate,
    required this.studentId,
    required this.studentName,
    this.status = AttendanceStatus.present,
    this.note,
    this.recordedBy = '',
  });

  /// `yyyy-MM-dd` for the Postgres `date` column.
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory AttendanceRecord.fromMap(Map<String, dynamic> m) {
    final raw = m['session_date']?.toString();
    return AttendanceRecord(
      id: m['id']?.toString() ?? '',
      schoolId: m['school_id']?.toString() ?? '',
      classLevel: m['class_level']?.toString() ?? '',
      subject: m['subject']?.toString() ?? '',
      sessionDate: raw != null ? (DateTime.tryParse(raw) ?? DateTime.now()) : DateTime.now(),
      studentId: m['student_id']?.toString() ?? '',
      studentName: m['student_name']?.toString() ?? '',
      status: AttendanceStatusX.fromWire(m['status']?.toString()),
      note: m['note']?.toString(),
      recordedBy: m['recorded_by']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'class_level': classLevel,
        'subject': subject,
        'session_date': dateKey(sessionDate),
        'student_id': studentId,
        'student_name': studentName,
        'status': status.wire,
        'note': note,
        'recorded_by': recordedBy,
        'updated_at': DateTime.now().toIso8601String(),
      };

  AttendanceRecord copyWith({
    AttendanceStatus? status,
    String? note,
    String? recordedBy,
  }) =>
      AttendanceRecord(
        id: id,
        schoolId: schoolId,
        classLevel: classLevel,
        subject: subject,
        sessionDate: sessionDate,
        studentId: studentId,
        studentName: studentName,
        status: status ?? this.status,
        note: note ?? this.note,
        recordedBy: recordedBy ?? this.recordedBy,
      );
}
