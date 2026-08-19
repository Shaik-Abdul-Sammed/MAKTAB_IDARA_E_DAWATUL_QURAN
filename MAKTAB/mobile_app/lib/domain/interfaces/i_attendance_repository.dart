import '../dtos/attendance_dto.dart';

abstract class IAttendanceRepository {
  Future<int> insertAttendance(AttendanceDTO attendance);
  Future<List<AttendanceDTO>> getAttendanceByDateAndBatch(String date, int batchId);
  Future<List<AttendanceDTO>> getAttendanceByStudent(int studentId);
  Future<int> updateAttendance(AttendanceDTO attendance);
}