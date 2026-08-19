import 'attendance_service.dart';
import 'quran_service.dart';

class ReportingService {
  final AttendanceService _attService = AttendanceService();
  final QuranService _quranService = QuranService();

  Future<Map<String, dynamic>> generateStudentReport(int studentId, String studentName) async {
    final attStats = await _attService.getAttendanceStats(studentId);
    final totalDays = (attStats['present'] ?? 0) + (attStats['absent'] ?? 0) + (attStats['leave'] ?? 0);
    double attPercentage = totalDays > 0 ? ((attStats['present'] ?? 0) / totalDays) * 100 : 0;
    
    final latestSurah = await _quranService.getLatestSurah(studentId);
    
    return {
      'studentName': studentName,
      'attendancePercentage': attPercentage.toStringAsFixed(1),
      'presentDays': attStats['present'],
      'absentDays': attStats['absent'],
      'latestSurah': latestSurah,
      'reportDate': DateTime.now().toIso8601String(),
    };
  }
}