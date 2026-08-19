import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maktab_app/providers/teacher_list_provider.dart';
import 'package:maktab_app/repositories/teacher_repository.dart';
import 'package:maktab_app/domain/dtos/user_dto.dart';

class MockTeacherRepository extends Mock implements TeacherRepository {}

void main() {
  late MockTeacherRepository mockRepo;
  late TeacherListProvider provider;

  final sampleTeachers = [
    UserDTO(id: 1, name: 'Ustad Ibrahim', pinHash: 'hash', role: 'teacher', createdAt: '2026-08-01', mobile: '9876543210', isActive: true),
    UserDTO(id: 2, name: 'Ustad Bilal', pinHash: 'hash', role: 'teacher', createdAt: '2026-08-01', mobile: '9876543211', isActive: false),
  ];

  setUp(() {
    mockRepo = MockTeacherRepository();
    provider = TeacherListProvider(mockRepo);
  });

  tearDown(() {
    provider.dispose();
  });

  group('TeacherListProvider Unit Tests', () {
    test('initial state is correct', () {
      expect(provider.status, TeacherListStatus.initial);
      expect(provider.teachers, isEmpty);
    });

    test('fetchTeachers updates state on success', () async {
      when(() => mockRepo.getAllTeachers()).thenAnswer((_) async => sampleTeachers);

      await provider.fetchTeachers();

      expect(provider.status, TeacherListStatus.success);
      expect(provider.teachers.length, 2);
      expect(provider.totalCount, 2);
      expect(provider.activeCount, 1);
      expect(provider.inactiveCount, 1);
    });

    test('fetchTeachers updates state on failure', () async {
      when(() => mockRepo.getAllTeachers()).thenThrow(Exception('DB Error'));

      await provider.fetchTeachers();

      expect(provider.status, TeacherListStatus.error);
      expect(provider.errorMessage, contains('DB Error'));
    });

    test('updateSearchQuery filters teacher list', () async {
      when(() => mockRepo.getAllTeachers()).thenAnswer((_) async => sampleTeachers);

      await provider.fetchTeachers();
      provider.updateSearchQuery('Ibrahim');

      expect(provider.filteredTeachers.length, 1);
      expect(provider.filteredTeachers.first.name, 'Ustad Ibrahim');
    });

    test('deleteTeacher performs optimistic deletion', () async {
      when(() => mockRepo.getAllTeachers()).thenAnswer((_) async => List.from(sampleTeachers));
      when(() => mockRepo.deleteUser(1)).thenAnswer((_) async => 1);

      await provider.fetchTeachers();
      await provider.deleteTeacher(1);

      verify(() => mockRepo.deleteUser(1)).called(1);
      expect(provider.teachers.any((t) => t.id == 1), isFalse);
    });
  });
}
