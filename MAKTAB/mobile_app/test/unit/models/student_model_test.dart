import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/student.dart';

void main() {
  group('Student Model Unit Tests', () {
    final studentMap = {
      'id': 1,
      'admission_number': 'ADM-1001',
      'name': 'Muhammad Zaid',
      'arabic_name': 'محمد زيد',
      'dob': '2015-05-10',
      'gender': 'Male',
      'father_name': 'Abdullah Khan',
      'phone': '9876543210',
      'batch_id': 2,
      'created_at': '2026-08-01',
    };

    test('fromMap should construct Student correctly', () {
      final s = Student.fromMap(studentMap);
      expect(s.id, 1);
      expect(s.admissionNumber, 'ADM-1001');
      expect(s.name, 'Muhammad Zaid');
      expect(s.arabicName, 'محمد زيد');
      expect(s.dob, '2015-05-10');
      expect(s.gender, 'Male');
      expect(s.fatherName, 'Abdullah Khan');
      expect(s.phone, '9876543210');
      expect(s.batchId, 2);
      expect(s.createdAt, '2026-08-01');
    });

    test('toMap should convert Student to Map correctly', () {
      final s = Student(
        id: 1,
        admissionNumber: 'ADM-1001',
        name: 'Muhammad Zaid',
        arabicName: 'محمد زيد',
        dob: '2015-05-10',
        gender: 'Male',
        fatherName: 'Abdullah Khan',
        phone: '9876543210',
        batchId: 2,
        createdAt: '2026-08-01',
      );
      final map = s.toMap();
      expect(map['id'], 1);
      expect(map['admission_number'], 'ADM-1001');
      expect(map['name'], 'Muhammad Zaid');
      expect(map['arabic_name'], 'محمد زيد');
      expect(map['father_name'], 'Abdullah Khan');
      expect(map['phone'], '9876543210');
      expect(map['batch_id'], 2);
      expect(map['created_at'], '2026-08-01');
    });

    test('copyWith should update fields correctly', () {
      final s = Student(
        id: 1,
        admissionNumber: 'ADM-1001',
        name: 'Muhammad Zaid',
        dob: '2015-05-10',
        gender: 'Male',
        createdAt: '2026-08-01',
      );
      final updated = s.copyWith(
        name: 'Zaid Khan',
        phone: '9998887770',
        batchId: 3,
      );
      expect(updated.id, 1);
      expect(updated.admissionNumber, 'ADM-1001');
      expect(updated.name, 'Zaid Khan');
      expect(updated.phone, '9998887770');
      expect(updated.batchId, 3);
    });

    test('fromMap with null optional fields should not crash', () {
      final s = Student.fromMap({
        'id': 5,
        'admission_number': 'ADM-1005',
        'name': 'Fatima',
        'dob': '2016-01-01',
        'gender': 'Female',
        'created_at': '2026-08-01',
      });
      expect(s.arabicName, isNull);
      expect(s.fatherName, isNull);
      expect(s.phone, isNull);
      expect(s.batchId, 1);
    });
  });
}
