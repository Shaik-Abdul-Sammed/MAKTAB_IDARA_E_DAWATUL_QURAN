import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../domain/dtos/user_dto.dart';
import '../repositories/teacher_repository.dart';

enum TeacherFormStatus { idle, loading, success, error }

class TeacherFormProvider extends ChangeNotifier {
  final TeacherRepository _repo;
  TeacherFormProvider(this._repo);

  TeacherFormStatus _status = TeacherFormStatus.idle;
  TeacherFormStatus get status => _status;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool get isLoading => _status == TeacherFormStatus.loading;

  String _hashPin(String pin) {
    const salt = 'idara_maktab_sec_salt_2026';
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> addTeacher({
    required String name,
    required String mobile,
    required String pin,
    String? photoPath,
  }) async {
    _status = TeacherFormStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final dto = UserDTO(
        name: name.trim(),
        pinHash: _hashPin(pin),
        role: 'teacher',
        createdAt: DateTime.now().toIso8601String(),
        mobile: mobile.trim(),
        isActive: true,
        photoPath: photoPath,
      );
      await _repo.insertUser(dto);
      _status = TeacherFormStatus.success;
    } catch (e) {
      _status = TeacherFormStatus.error;
      _errorMessage = 'Failed to save teacher. Please try again.';
    }
    notifyListeners();
  }

  Future<void> updateTeacher({
    required UserDTO existing,
    required String name,
    required String mobile,
    String? newPin,
    String? photoPath,
  }) async {
    _status = TeacherFormStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final updated = UserDTO(
        id: existing.id,
        name: name.trim(),
        pinHash: (newPin != null && newPin.trim().isNotEmpty)
            ? _hashPin(newPin.trim())
            : existing.pinHash,
        role: existing.role,
        createdAt: existing.createdAt,
        mobile: mobile.trim(),
        isActive: existing.isActive,
        photoPath: photoPath ?? existing.photoPath,
      );
      await _repo.updateUser(updated);
      _status = TeacherFormStatus.success;
    } catch (e) {
      _status = TeacherFormStatus.error;
      _errorMessage = 'Failed to update teacher. Please try again.';
    }
    notifyListeners();
  }

  void reset() {
    _status = TeacherFormStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }
}
