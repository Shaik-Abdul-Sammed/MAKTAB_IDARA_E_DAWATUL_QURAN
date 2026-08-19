import '../dtos/student_dto.dart';

abstract class IStudentRepository {
  Future<int> insertStudent(StudentDTO student);
  Future<List<StudentDTO>> getStudentsByBatch(int batchId);
  Future<StudentDTO?> getStudentById(int id);
  Future<int> updateStudent(StudentDTO student);
  Future<int> deleteStudent(int id);
}