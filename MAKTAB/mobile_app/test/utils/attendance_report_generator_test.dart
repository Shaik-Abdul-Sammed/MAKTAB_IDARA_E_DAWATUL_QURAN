import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/utils/attendance_report_generator.dart';

void main() {
  group('AttendanceReportGenerator Tests', () {
    test('formatDate converts yyyy-MM-dd to dd MMMM yyyy correctly', () {
      final formatted = AttendanceReportGenerator.formatDate('2026-08-21');
      expect(formatted, equals('21 August 2026'));
    });

    test('generateTextReport formats attendance counts, rate, and lists accurately', () {
      final s1 = Student(id: 1, admissionNumber: 'ADM-1001', name: 'Student 1', createdAt: '2026-01-01');
      final s2 = Student(id: 2, admissionNumber: 'ADM-1002', name: 'Student 2', createdAt: '2026-01-01');
      final s3 = Student(id: 3, admissionNumber: 'ADM-1003', name: 'Student 3', createdAt: '2026-01-01');
      final s4 = Student(id: 4, admissionNumber: 'ADM-1004', name: 'Student 4', createdAt: '2026-01-01');

      final statuses = <int, String>{
        1: 'Present',
        2: 'Present',
        3: 'Absent',
        4: 'Leave',
      };

      final report = AttendanceReportGenerator.generateTextReport(
        rawDate: '2026-08-21',
        batchName: 'Batch A - Morning',
        teacherName: 'Maulana Ahmed',
        students: [s1, s2, s3, s4],
        studentStatuses: statuses,
        generatedAt: '21 August 2026, 06:30 PM',
      );

      expect(report, contains('MAKTAB IDARA E DAWATUL QURAN'));
      expect(report, contains('Date             : 21 August 2026'));
      expect(report, contains('Batch            : Batch A - Morning'));
      expect(report, contains('Teacher          : Maulana Ahmed'));
      expect(report, contains('Total Students   : 4'));
      expect(report, contains('Present          : 2'));
      expect(report, contains('Absent           : 1'));
      expect(report, contains('Leave            : 1'));
      expect(report, contains('Attendance Rate  : 50.0%'));

      expect(report, contains('ABSENT STUDENTS (1)'));
      expect(report, contains('1. [ADM-1003] Student 3'));

      expect(report, contains('LEAVE STUDENTS (1)'));
      expect(report, contains('1. [ADM-1004] Student 4'));

      expect(report, contains('MASTER ATTENDANCE LIST'));
      expect(report, contains('ADM-1001'));
      expect(report, contains('PRESENT'));
      expect(report, contains('ABSENT'));
      expect(report, contains('LEAVE'));
    });

    test('generateTextReport handles empty student list without crashing', () {
      final report = AttendanceReportGenerator.generateTextReport(
        rawDate: '2026-08-21',
        batchName: 'Empty Batch',
        teacherName: 'Teacher Name',
        students: [],
        studentStatuses: {},
      );

      expect(report, contains('ATTENDANCE NOT RECORDED'));
      expect(report, contains('No student attendance records available'));
    });

    test('generatePdfReport builds a valid PDF document', () async {
      final s1 = Student(id: 1, admissionNumber: 'ADM-1001', name: 'Student 1', createdAt: '2026-01-01');
      final doc = await AttendanceReportGenerator.generatePdfReport(
        rawDate: '2026-08-21',
        batchName: 'Batch A - Morning',
        teacherName: 'Maulana Ahmed',
        students: [s1],
        studentStatuses: {1: 'Present'},
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
