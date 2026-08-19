import '../repositories/attendance_repository.dart';
import '../models/attendance.dart';

class AttendanceService {
  final AttendanceRepository _repository = AttendanceRepository();

  Future<void> markBatchAttendance(List<Attendance> attendanceList) async {
    for (var att in attendanceList) {
      await _repository.insertAttendance(att);
    }
  }

  Future<List<Attendance>> getStudentAttendanceHistory(int studentId) async {
    return await _repository.getAttendanceByStudent(studentId);
  }
  
  Future<Map<String, int>> getAttendanceStats(int studentId) async {
    final history = await getStudentAttendanceHistory(studentId);
    int present = 0;
    int absent = 0;
    int leave = 0;
    
    for (var att in history) {
      if (att.status == 'Present') present++;
      if (att.status == 'Absent') absent++;
      if (att.status == 'Leave') leave++;
    }
    
    return {'present': present, 'absent': absent, 'leave': leave};
  }
}