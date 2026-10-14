import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/models/attendance_record.dart';

void main() {
  group('AttendanceRecord', () {
    test('dateKey formats as yyyy-MM-dd zero-padded', () {
      expect(AttendanceRecord.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(AttendanceRecord.dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('status wire round-trips through fromWire', () {
      for (final s in AttendanceStatus.values) {
        expect(AttendanceStatusX.fromWire(s.wire), s);
      }
    });

    test('fromWire defaults unknown/null to present', () {
      expect(AttendanceStatusX.fromWire(null), AttendanceStatus.present);
      expect(AttendanceStatusX.fromWire('garbage'), AttendanceStatus.present);
    });

    test('toMap -> fromMap preserves the register fields', () {
      final r = AttendanceRecord(
        id: 'a1',
        schoolId: 'sch1',
        classLevel: 'Form 5',
        subject: '',
        sessionDate: DateTime(2026, 10, 14),
        studentId: 'stu1',
        studentName: 'Ada Lovelace',
        status: AttendanceStatus.late,
        recordedBy: 'Mr Smith',
      );
      final back = AttendanceRecord.fromMap(r.toMap());
      expect(back.schoolId, 'sch1');
      expect(back.classLevel, 'Form 5');
      expect(back.studentId, 'stu1');
      expect(back.studentName, 'Ada Lovelace');
      expect(back.status, AttendanceStatus.late);
      expect(AttendanceRecord.dateKey(back.sessionDate), '2026-10-14');
    });

    test('empty subject means whole-day register', () {
      final r = AttendanceRecord(
        id: '',
        schoolId: 's',
        classLevel: 'c',
        sessionDate: DateTime(2026, 10, 14),
        studentId: 'x',
        studentName: 'y',
      );
      expect(r.subject, '');
    });
  });
}
