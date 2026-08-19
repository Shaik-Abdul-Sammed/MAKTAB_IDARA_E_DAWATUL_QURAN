import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/student.dart';

void main() {
  group('Student Model Tests', () {
    test('Student can be created and serialized', () {
      final student = Student(
        id: 1,
        admissionNumber: '1001',
        name: 'Abdul',
        arabicName: 'عبد',
        dob: '2010-01-01',
        gender: 'Male',
        fatherName: 'Rahim',
        phone: '1234567890',
        batchId: 1,
        createdAt: '2023-01-01 10:00:00',
      );

      final map = student.toMap();
      
      expect(map['id'], 1);
      expect(map['admission_number'], '1001');
      expect(map['name'], 'Abdul');
      expect(map['arabic_name'], 'عبد');
      expect(map['dob'], '2010-01-01');
      expect(map['gender'], 'Male');
      expect(map['father_name'], 'Rahim');
      expect(map['phone'], '1234567890');
      expect(map['batch_id'], 1);
      expect(map['created_at'], '2023-01-01 10:00:00');

      final deserializedStudent = Student.fromMap(map);
      
      expect(deserializedStudent.id, 1);
      expect(deserializedStudent.admissionNumber, '1001');
      expect(deserializedStudent.name, 'Abdul');
      expect(deserializedStudent.arabicName, 'عبد');
      expect(deserializedStudent.dob, '2010-01-01');
      expect(deserializedStudent.gender, 'Male');
      expect(deserializedStudent.fatherName, 'Rahim');
      expect(deserializedStudent.phone, '1234567890');
      expect(deserializedStudent.batchId, 1);
      expect(deserializedStudent.createdAt, '2023-01-01 10:00:00');
    });

    test('Student copyWith works correctly', () {
      final student = Student(
        id: 1,
        admissionNumber: '1001',
        name: 'Abdul',
        createdAt: '2023-01-01 10:00:00',
      );

      final updatedStudent = student.copyWith(
        name: 'Abdul Rahman', 
        phone: '9876543210'
      );
      
      expect(updatedStudent.id, 1);
      expect(updatedStudent.admissionNumber, '1001');
      expect(updatedStudent.name, 'Abdul Rahman');
      expect(updatedStudent.phone, '9876543210');
      expect(updatedStudent.createdAt, '2023-01-01 10:00:00');
    });
  });
}
