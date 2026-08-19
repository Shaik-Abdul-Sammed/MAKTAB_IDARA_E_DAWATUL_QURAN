import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/student.dart';

void main() {
  group('Student Model Tests', () {
    test('Student serialization and deserialization', () {
      final student = Student(
        id: 1,
        admissionNumber: 'ADM123',
        name: 'John Doe',
        batchId: 2,
        createdAt: '2023-10-27T10:00:00Z',
      );

      final map = student.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'John Doe');
      expect(map['batch_id'], 2);
      expect(map['admission_number'], 'ADM123');

      final deserializedStudent = Student.fromMap(map);
      expect(deserializedStudent.id, 1);
      expect(deserializedStudent.name, 'John Doe');
      expect(deserializedStudent.batchId, 2);
      expect(deserializedStudent.admissionNumber, 'ADM123');
    });
  });
}
