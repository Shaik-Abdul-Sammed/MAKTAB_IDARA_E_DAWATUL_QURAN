import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/attendance.dart';

void main() {
  group('Attendance Model Tests', () {
    test('Attendance can be created and serialized', () {
      final attendance = Attendance(
        id: 1,
        studentId: 2,
        date: '2023-10-25',
        status: 'Present',
        remarks: 'On time',
      );

      final map = attendance.toMap();
      
      expect(map['id'], 1);
      expect(map['student_id'], 2);
      expect(map['date'], '2023-10-25');
      expect(map['status'], 'Present');
      expect(map['remarks'], 'On time');

      final deserialized = Attendance.fromMap(map);
      
      expect(deserialized.id, 1);
      expect(deserialized.studentId, 2);
      expect(deserialized.date, '2023-10-25');
      expect(deserialized.status, 'Present');
      expect(deserialized.remarks, 'On time');
    });
  });
}
