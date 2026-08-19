import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:crypto/crypto.dart';

class ExcelImportResult {
  final int successCount;
  final int errorCount;
  final List<String> errors;

  ExcelImportResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
  });
}

class ExcelImportService {
  final StudentRepository _studentRepository = StudentRepository();
  final UserRepository _userRepository = UserRepository();

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Parses CSV or XLSX data into rows of key-value maps
  Future<List<Map<String, String>>> parseFileToRows(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist');
    }

    final bytes = await file.readAsBytes();
    final fileName = filePath.toLowerCase();

    if (fileName.endsWith('.csv') || fileName.endsWith('.txt')) {
      return _parseCsv(utf8.decode(bytes, allowMalformed: true));
    } else if (fileName.endsWith('.xlsx')) {
      return _parseXlsx(bytes);
    } else {
      // Fallback: try CSV first, if fails try XLSX
      try {
        return _parseCsv(utf8.decode(bytes, allowMalformed: true));
      } catch (_) {
        return _parseXlsx(bytes);
      }
    }
  }

  List<Map<String, String>> _parseCsv(String content) {
    final lines = LineSplitter.split(content).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = lines.first.split(',').map((h) => h.trim().toLowerCase().replaceAll('"', '')).toList();
    final List<Map<String, String>> rows = [];

    for (int i = 1; i < lines.length; i++) {
      final values = lines[i].split(',').map((v) => v.trim().replaceAll('"', '')).toList();
      final Map<String, String> row = {};
      for (int j = 0; j < headers.length; j++) {
        if (j < values.length) {
          row[headers[j]] = values[j];
        }
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }
    return rows;
  }

  List<Map<String, String>> _parseXlsx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? sharedStringsFile;
      ArchiveFile? sheetFile;

      for (final file in archive) {
        if (file.name.contains('sharedStrings.xml')) {
          sharedStringsFile = file;
        } else if (file.name.contains('sheet1.xml') || file.name.contains('sheet.xml')) {
          sheetFile ??= file;
        }
      }

      final List<String> sharedStrings = [];
      if (sharedStringsFile != null) {
        final content = utf8.decode(sharedStringsFile.content as List<int>);
        final matches = RegExp(r'<t[^>]*>(.*?)</t>').allMatches(content);
        for (final m in matches) {
          sharedStrings.add(m.group(1) ?? '');
        }
      }

      if (sheetFile == null) return [];
      final sheetContent = utf8.decode(sheetFile.content as List<int>);

      // Extract row data
      final rowMatches = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(sheetContent);
      final List<List<String>> rawGrid = [];

      for (final rm in rowMatches) {
        final rowXml = rm.group(1) ?? '';
        final cellMatches = RegExp(r'<c[^>]*?(?:t="([^"]*)")?[^>]*>(?:<v>(.*?)</v>)?</c>', dotAll: true).allMatches(rowXml);
        final List<String> cellValues = [];

        for (final cm in cellMatches) {
          final type = cm.group(1);
          final val = cm.group(2) ?? '';
          if (type == 's' && val.isNotEmpty) {
            final idx = int.tryParse(val) ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              cellValues.add(sharedStrings[idx]);
            } else {
              cellValues.add(val);
            }
          } else {
            cellValues.add(val);
          }
        }
        if (cellValues.isNotEmpty) {
          rawGrid.add(cellValues);
        }
      }

      if (rawGrid.isEmpty) return [];

      final headers = rawGrid.first.map((h) => h.trim().toLowerCase()).toList();
      final List<Map<String, String>> result = [];

      for (int i = 1; i < rawGrid.length; i++) {
        final row = rawGrid[i];
        final Map<String, String> rowMap = {};
        for (int j = 0; j < headers.length; j++) {
          if (j < row.length) {
            rowMap[headers[j]] = row[j];
          }
        }
        if (rowMap.isNotEmpty) {
          result.add(rowMap);
        }
      }
      return result;
    } catch (e) {
      throw Exception('Failed to decode XLSX file format: $e');
    }
  }

  /// Bulk Import Students
  Future<ExcelImportResult> importStudents(List<Map<String, String>> rows) async {
    int success = 0;
    int error = 0;
    final List<String> errorMsgs = [];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = row['name'] ?? row['student_name'] ?? row['full_name'];
      final adm = row['admission_number'] ?? row['adm_no'] ?? row['id'] ?? 'ADM-${DateTime.now().millisecondsSinceEpoch + i}';

      if (name == null || name.trim().isEmpty) {
        error++;
        errorMsgs.add('Row ${i + 1}: Student name missing');
        continue;
      }

      try {
        final student = Student(
          admissionNumber: adm.trim(),
          name: name.trim(),
          arabicName: row['arabic_name'],
          dob: row['dob'],
          gender: row['gender'] ?? 'Male',
          fatherName: row['father_name'] ?? row['parent_name'] ?? row['guardian_name'],
          phone: row['phone'] ?? row['mobile'] ?? row['guardian_phone'],
          guardianName: row['guardian_name'] ?? row['parent_name'],
          guardianPhone: row['guardian_phone'] ?? row['phone'],
          createdAt: DateTime.now().toIso8601String(),
        );
        await _studentRepository.insertStudent(student);
        success++;
      } catch (e) {
        error++;
        errorMsgs.add('Row ${i + 1} ($name): $e');
      }
    }

    return ExcelImportResult(successCount: success, errorCount: error, errors: errorMsgs);
  }

  /// Bulk Import Teachers
  Future<ExcelImportResult> importTeachers(List<Map<String, String>> rows) async {
    int success = 0;
    int error = 0;
    final List<String> errorMsgs = [];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = row['name'] ?? row['teacher_name'] ?? row['full_name'];
      final mobile = row['mobile'] ?? row['phone'] ?? row['contact'];
      final pin = row['pin'] ?? '1234';

      if (name == null || name.trim().isEmpty) {
        error++;
        errorMsgs.add('Row ${i + 1}: Teacher name missing');
        continue;
      }

      try {
        final user = User(
          name: name.trim(),
          pinHash: _hashPin(pin),
          role: 'teacher',
          createdAt: DateTime.now().toIso8601String(),
          mobile: mobile?.trim(),
          isActive: true,
        );
        await _userRepository.insertUser(user);
        success++;
      } catch (e) {
        error++;
        errorMsgs.add('Row ${i + 1} ($name): $e');
      }
    }

    return ExcelImportResult(successCount: success, errorCount: error, errors: errorMsgs);
  }
}
