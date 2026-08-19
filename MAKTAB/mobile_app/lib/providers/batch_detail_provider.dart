import 'package:flutter/foundation.dart';
import '../models/batch.dart';
import '../models/student.dart';
import '../domain/dtos/user_dto.dart';
import '../repositories/batch_repository.dart';
import '../repositories/teacher_repository.dart';
import '../repositories/student_repository.dart';

class BatchDetailProvider extends ChangeNotifier {
  final BatchRepository _batchRepo;
  final TeacherRepository _teacherRepo;
  final StudentRepository _studentRepo;

  BatchDetailProvider(this._batchRepo, this._teacherRepo, this._studentRepo);

  Batch? _batch;
  Batch? get batch => _batch;

  UserDTO? _teacher;
  UserDTO? get teacher => _teacher;

  List<Student> _students = [];
  List<Student> get students => List.unmodifiable(_students);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get hasBatch => _batch != null;

  Future<void> fetchBatchDetails(int batchId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _batch = await _batchRepo.getBatchById(batchId);
      if (_batch == null) {
        _errorMessage = 'Batch record not found.';
      } else {
        if (_batch!.teacherId != null) {
          _teacher = await _teacherRepo.getUserById(_batch!.teacherId!);
        } else {
          _teacher = null;
        }
        _students = await _studentRepo.getStudentsByBatch(batchId);
      }
    } catch (e) {
      _errorMessage = 'Failed to load batch overview.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteCurrentBatch() async {
    if (_batch?.id == null) throw Exception('No batch loaded.');
    await _batchRepo.deleteBatch(_batch!.id!);
  }
}
