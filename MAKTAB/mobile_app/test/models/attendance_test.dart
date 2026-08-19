import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/attendance.dart';

void main() {
  group('Attendance Model Tests', () {
    test('Attendance serialization and deserialization', () {
      final attendance = Attendance(
        id: 1,
        studentId: 2,
        date: '2023-10-27',
        status: 'present',
        remarks: 'On time',
      );

      final map = attendance.toMap();
      expect(map['id'], 1);
      expect(map['student_id'], 2);
      expect(map['status'], 'present');

      final deserializedAttendance = Attendance.fromMap(map);
      expect(deserializedAttendance.id, 1);
      expect(deserializedAttendance.studentId, 2);
      expect(deserializedAttendance.status, 'present');
    });
  });
}
