import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../repositories/student_repository.dart';

enum StudentListStatus { initial, loading, success, error }

class StudentListProvider extends ChangeNotifier {
  final StudentRepository _repo;
  StudentListProvider(this._repo);

  StudentListStatus _status = StudentListStatus.initial;
  StudentListStatus get status => _status;

  List<Student> _students = [];
  List<Student> get students => List.unmodifiable(_students);

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int? _selectedBatchFilter;
  int? get selectedBatchFilter => _selectedBatchFilter;

  List<Student> get filteredStudents {
    return _students.where((s) {
      final matchesBatch = _selectedBatchFilter == null || s.batchId == _selectedBatchFilter;
      if (!matchesBatch) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.admissionNumber.toLowerCase().contains(q) ||
          (s.fatherName ?? '').toLowerCase().contains(q) ||
          (s.phone ?? '').contains(q);
    }).toList();
  }

  int get totalCount => _students.length;
  int get maleCount => _students.where((s) => (s.gender ?? '').toLowerCase() == 'male').length;
  int get femaleCount => _students.where((s) => (s.gender ?? '').toLowerCase() == 'female').length;

  Future<void> fetchStudents() async {
    _status = StudentListStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      _students = await _repo.getAllStudents();
      _status = StudentListStatus.success;
    } catch (e) {
      _status = StudentListStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setBatchFilter(int? batchId) {
    _selectedBatchFilter = batchId;
    notifyListeners();
  }

  Future<void> deleteStudent(int id) async {
    final index = _students.indexWhere((s) => s.id == id);
    Student? removed;
    if (index != -1) {
      removed = _students[index];
      _students.removeAt(index);
      notifyListeners();
    }
    try {
      await _repo.deleteStudent(id);
    } catch (e) {
      if (removed != null && index != -1) {
        _students.insert(index, removed);
        notifyListeners();
      }
      rethrow;
    }
  }
}
