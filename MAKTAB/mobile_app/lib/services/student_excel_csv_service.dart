import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student.dart';
import '../repositories/student_repository.dart';

class StudentExcelCsvService {
  static final StudentRepository _studentRepository = StudentRepository();

  /// Exports a list of students to a CSV file (Excel-compatible) and opens share sheet.
  static Future<void> exportStudentsToCsv({
    required BuildContext context,
    required List<Student> students,
    String filenamePrefix = 'Maktab_Students',
  }) async {
    try {
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No student data available to export.')),
        );
        return;
      }

      List<List<dynamic>> rows = [
        [
          'Admission Number',
          'Student Name',
          'Arabic Name',
          'DOB',
          'Gender',
          'Father Name',
          'Phone',
          'Guardian Name',
          'Guardian Phone',
          'Fees Amount',
          'Batch ID',
          'Notes'
        ],
      ];

      for (var s in students) {
        rows.add([
          s.admissionNumber,
          s.name,
          s.arabicName ?? '',
          s.dob ?? '',
          s.gender ?? '',
          s.fatherName ?? '',
          s.phone ?? '',
          s.guardianName ?? '',
          s.guardianPhone ?? '',
          s.feesAmount ?? 0,
          s.batchId,
          s.teacherNotes ?? '',
        ]);
      }

      String csvData = excel.encoder.convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/${filenamePrefix}_$timestamp.csv');

      await file.writeAsString(csvData);

      if (context.mounted) {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Maktab Student List Excel/CSV Export',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export student data: $e')),
        );
      }
    }
  }

  /// Downloads a sample CSV import template for filling student details.
  static Future<void> exportSampleTemplate(BuildContext context) async {
    List<List<dynamic>> sampleRows = [
      [
        'Admission Number',
        'Student Name',
        'Arabic Name',
        'DOB (YYYY-MM-DD)',
        'Gender',
        'Father Name',
        'Phone',
        'Guardian Name',
        'Guardian Phone',
        'Fees Amount',
        'Batch ID',
        'Notes'
      ],
      [
        'ADM-101',
        'MOHAMMED ALI',
        'محمد علي',
        '2015-05-10',
        'Male',
        'ABDULLAH',
        '9876543210',
        'ABDULLAH',
        '9876543210',
        '500',
        '1',
        'Punctual and diligent student'
      ],
      [
        'ADM-102',
        'FATIMA ZAHRA',
        'فاطمة الزهراء',
        '2016-08-15',
        'Female',
        'IBRAHIM',
        '9876543211',
        'IBRAHIM',
        '9876543211',
        '500',
        '1',
        'Memorizing Surah Al-Mulk'
      ],
    ];

    String csvData = excel.encoder.convert(sampleRows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Maktab_Student_Import_Template.csv');
    await file.writeAsString(csvData);

    if (context.mounted) {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Maktab Student Batch Import Excel/CSV Template',
      );
    }
  }

  /// Imports students from an Excel/CSV file selected by the user.
  static Future<int> importStudentsFromCsv({
    required BuildContext context,
    int? defaultBatchId,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result == null || result.files.single.path == null) {
        return 0;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      List<List<dynamic>> fields = excel.decoder.convert(content);

      if (fields.length <= 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is empty or missing data rows.')),
          );
        }
        return 0;
      }

      int successCount = 0;

      // Skip header row
      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.isEmpty || row.length < 2) continue;

        final admNo = row[0].toString().trim();
        final name = row[1].toString().trim();
        if (name.isEmpty) continue;

        final arabicName = row.length > 2 ? row[2].toString().trim() : null;
        final dob = row.length > 3 ? row[3].toString().trim() : null;
        final gender = row.length > 4 ? row[4].toString().trim() : 'Male';
        final fatherName = row.length > 5 ? row[5].toString().trim() : null;
        final phone = row.length > 6 ? row[6].toString().trim() : null;
        final gName = row.length > 7 ? row[7].toString().trim() : fatherName;
        final gPhone = row.length > 8 ? row[8].toString().trim() : phone;
        final fees = row.length > 9 ? int.tryParse(row[9].toString().trim()) ?? 0 : 0;
        final batchId = row.length > 10 ? (int.tryParse(row[10].toString().trim()) ?? (defaultBatchId ?? 1)) : (defaultBatchId ?? 1);
        final notes = row.length > 11 ? row[11].toString().trim() : null;

        final student = Student(
          admissionNumber: admNo.isNotEmpty ? admNo : 'ADM-${DateTime.now().millisecondsSinceEpoch % 100000}',
          name: name,
          arabicName: arabicName,
          dob: dob,
          gender: gender,
          fatherName: fatherName,
          phone: phone,
          guardianName: gName,
          guardianPhone: gPhone,
          feesAmount: fees,
          batchId: batchId,
          teacherNotes: notes,
          createdAt: DateTime.now().toIso8601String(),
        );

        await _studentRepository.insertStudent(student);
        successCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $successCount student(s) into database!'),
            backgroundColor: const Color(0xFF004D40),
          ),
        );
      }

      return successCount;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
      return 0;
    }
  }
}
