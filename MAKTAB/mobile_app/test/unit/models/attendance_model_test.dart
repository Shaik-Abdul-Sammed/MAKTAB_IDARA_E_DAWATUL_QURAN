import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/attendance.dart';

void main() {
  group('Attendance Model Unit Tests', () {
    final attMap = {
      'id': 100,
      'student_id': 1,
      'date': '2026-08-05',
      'status': 'Present',
      'remarks': 'On time',
    };

    test('fromMap should construct Attendance correctly', () {
      final a = Attendance.fromMap(attMap);
      expect(a.id, 100);
      expect(a.studentId, 1);
      expect(a.date, '2026-08-05');
      expect(a.status, 'Present');
      expect(a.remarks, 'On time');
    });

    test('toMap should convert Attendance to Map correctly', () {
      final a = Attendance(
        id: 100,
        studentId: 1,
        date: '2026-08-05',
        status: 'Present',
        remarks: 'On time',
      );
      final map = a.toMap();
      expect(map['id'], 100);
      expect(map['student_id'], 1);
      expect(map['date'], '2026-08-05');
      expect(map['status'], 'Present');
      expect(map['remarks'], 'On time');
    });
  });
}
