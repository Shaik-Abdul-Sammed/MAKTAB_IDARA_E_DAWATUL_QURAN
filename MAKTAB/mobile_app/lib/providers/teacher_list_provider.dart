import 'package:flutter/foundation.dart';
import '../domain/dtos/user_dto.dart';
import '../repositories/teacher_repository.dart';

enum TeacherListStatus { initial, loading, success, error }

class TeacherListProvider extends ChangeNotifier {
  final TeacherRepository _repo;
  TeacherListProvider(this._repo);

  TeacherListStatus _status = TeacherListStatus.initial;
  TeacherListStatus get status => _status;

  List<UserDTO> _teachers = [];
  List<UserDTO> get teachers => List.unmodifiable(_teachers);

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  List<UserDTO> get filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    final q = _searchQuery.toLowerCase();
    return _teachers
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            (t.mobile ?? '').contains(q))
        .toList();
  }

  int get totalCount => _teachers.length;
  int get activeCount => _teachers.where((t) => t.isActive).length;
  int get inactiveCount => _teachers.where((t) => !t.isActive).length;

  Future<void> fetchTeachers() async {
    _status = TeacherListStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      _teachers = await _repo.getAllTeachers();
      _status = TeacherListStatus.success;
    } catch (e) {
      _status = TeacherListStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Optimistic delete: removes from local list first, rolls back on error.
  Future<void> deleteTeacher(int id) async {
    final index = _teachers.indexWhere((t) => t.id == id);
    UserDTO? removed;
    if (index != -1) {
      removed = _teachers[index];
      _teachers.removeAt(index);
      notifyListeners();
    }
    try {
      await _repo.deleteUser(id);
    } catch (e) {
      if (removed != null && index != -1) {
        _teachers.insert(index, removed);
        notifyListeners();
      }
      rethrow;
    }
  }
}
