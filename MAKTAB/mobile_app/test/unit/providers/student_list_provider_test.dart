import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maktab_app/providers/student_list_provider.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/models/student.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

void main() {
  late MockStudentRepository mockStudentRepo;
  late StudentListProvider provider;

  final List<Student> sampleStudents = [
    Student(id: 1, admissionNumber: 'ADM-1', name: 'Zaid', dob: '2015-01-01', gender: 'Male', batchId: 10, createdAt: '2026-08-01'),
    Student(id: 2, admissionNumber: 'ADM-2', name: 'Fatima', dob: '2016-01-01', gender: 'Female', batchId: 20, createdAt: '2026-08-01'),
  ];

  setUp(() {
    mockStudentRepo = MockStudentRepository();
    provider = StudentListProvider(mockStudentRepo);
  });

  tearDown(() {
    provider.dispose();
  });

  group('StudentListProvider Unit Tests', () {
    test('fetchStudents updates state on success', () async {
      when(() => mockStudentRepo.getAllStudents()).thenAnswer((_) async => sampleStudents);

      await provider.fetchStudents();

      expect(provider.status, StudentListStatus.success);
      expect(provider.students.length, 2);
      expect(provider.totalCount, 2);
      expect(provider.maleCount, 1);
      expect(provider.femaleCount, 1);
    });

    test('setBatchFilter filters students correctly', () async {
      when(() => mockStudentRepo.getAllStudents()).thenAnswer((_) async => sampleStudents);

      await provider.fetchStudents();
      provider.setBatchFilter(10);

      expect(provider.filteredStudents.length, 1);
      expect(provider.filteredStudents.first.name, 'Zaid');
    });

    test('updateSearchQuery filters students correctly', () async {
      when(() => mockStudentRepo.getAllStudents()).thenAnswer((_) async => sampleStudents);

      await provider.fetchStudents();
      provider.updateSearchQuery('Fatima');

      expect(provider.filteredStudents.length, 1);
      expect(provider.filteredStudents.first.name, 'Fatima');
    });

    test('deleteStudent performs optimistic removal', () async {
      when(() => mockStudentRepo.getAllStudents()).thenAnswer((_) async => List.from(sampleStudents));
      when(() => mockStudentRepo.deleteStudent(1)).thenAnswer((_) async => 1);

      await provider.fetchStudents();
      await provider.deleteStudent(1);

      verify(() => mockStudentRepo.deleteStudent(1)).called(1);
      expect(provider.students.any((s) => s.id == 1), isFalse);
    });
  });
}
