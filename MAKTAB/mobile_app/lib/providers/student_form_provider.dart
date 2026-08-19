import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../repositories/student_repository.dart';

enum StudentFormStatus { idle, loading, success, error }

class StudentFormProvider extends ChangeNotifier {
  final StudentRepository _repo;
  StudentFormProvider(this._repo);

  StudentFormStatus _status = StudentFormStatus.idle;
  StudentFormStatus get status => _status;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool get isLoading => _status == StudentFormStatus.loading;

  Future<void> addStudent({
    required String admissionNumber,
    required String name,
    String? arabicName,
    String? dob,
    String? gender,
    String? fatherName,
    String? phone,
    String? guardianName,
    String? guardianPhone,
    String? photoPath,
    int? batchId,
  }) async {
    _status = StudentFormStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final student = Student(
        admissionNumber: admissionNumber.trim(),
        name: name.trim(),
        arabicName: arabicName?.trim().isEmpty ?? true ? null : arabicName?.trim(),
        dob: dob,
        gender: gender,
        fatherName: fatherName?.trim().isEmpty ?? true ? null : fatherName?.trim(),
        phone: phone?.trim().isEmpty ?? true ? null : phone?.trim(),
        guardianName: guardianName?.trim().isEmpty ?? true ? null : guardianName?.trim(),
        guardianPhone: guardianPhone?.trim().isEmpty ?? true ? null : guardianPhone?.trim(),
        photoPath: photoPath,
        batchId: batchId,
        createdAt: DateTime.now().toIso8601String(),
      );
      await _repo.insertStudent(student);
      _status = StudentFormStatus.success;
    } catch (e) {
      _status = StudentFormStatus.error;
      _errorMessage = 'Failed to save student record. Please try again.';
    }
    notifyListeners();
  }

  Future<void> updateStudent({
    required Student existing,
    required String admissionNumber,
    required String name,
    String? arabicName,
    String? dob,
    String? gender,
    String? fatherName,
    String? phone,
    String? guardianName,
    String? guardianPhone,
    String? photoPath,
    int? batchId,
  }) async {
    _status = StudentFormStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final updated = existing.copyWith(
        admissionNumber: admissionNumber.trim(),
        name: name.trim(),
        arabicName: arabicName?.trim().isEmpty ?? true ? null : arabicName?.trim(),
        dob: dob,
        gender: gender,
        fatherName: fatherName?.trim().isEmpty ?? true ? null : fatherName?.trim(),
        phone: phone?.trim().isEmpty ?? true ? null : phone?.trim(),
        guardianName: guardianName?.trim().isEmpty ?? true ? null : guardianName?.trim(),
        guardianPhone: guardianPhone?.trim().isEmpty ?? true ? null : guardianPhone?.trim(),
        photoPath: photoPath,
        batchId: batchId,
      );
      await _repo.updateStudent(updated);
      _status = StudentFormStatus.success;
    } catch (e) {
      _status = StudentFormStatus.error;
      _errorMessage = 'Failed to update student details. Please try again.';
    }
    notifyListeners();
  }

  void reset() {
    _status = StudentFormStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }
}
