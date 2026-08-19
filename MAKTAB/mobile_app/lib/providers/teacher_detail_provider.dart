import 'package:flutter/foundation.dart';
import '../domain/dtos/user_dto.dart';
import '../repositories/teacher_repository.dart';

class TeacherDetailProvider extends ChangeNotifier {
  final TeacherRepository _repo;
  TeacherDetailProvider(this._repo);

  UserDTO? _teacher;
  UserDTO? get teacher => _teacher;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get hasTeacher => _teacher != null;

  Future<void> fetchTeacher(int id) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final result = await _repo.getUserById(id);
      if (result == null) {
        _errorMessage = 'Teacher record not found.';
      } else {
        _teacher = result;
      }
    } catch (e) {
      _errorMessage = 'Failed to load teacher details.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleActiveStatus() async {
    if (_teacher == null) return;
    final updated = UserDTO(
      id: _teacher!.id,
      name: _teacher!.name,
      pinHash: _teacher!.pinHash,
      role: _teacher!.role,
      createdAt: _teacher!.createdAt,
      mobile: _teacher!.mobile,
      isActive: !_teacher!.isActive,
    );
    try {
      await _repo.updateUser(updated);
      _teacher = updated;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCurrentTeacher() async {
    if (_teacher?.id == null) throw Exception('No teacher loaded.');
    await _repo.deleteUser(_teacher!.id!);
  }

  void clear() {
    _teacher = null;
    _errorMessage = '';
    _isLoading = false;
    notifyListeners();
  }
}
