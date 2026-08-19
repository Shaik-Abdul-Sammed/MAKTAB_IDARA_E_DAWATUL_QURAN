import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/quran_progress.dart';
import '../repositories/quran_progress_repository.dart';

enum QuranProgressStatus { initial, loading, success, error }

class QuranProgressProvider extends ChangeNotifier {
  final QuranProgressRepository _repo;
  QuranProgressProvider(this._repo);

  QuranProgressStatus _status = QuranProgressStatus.initial;
  QuranProgressStatus get status => _status;

  List<QuranProgress> _progressHistory = [];
  List<QuranProgress> get progressHistory => List.unmodifiable(_progressHistory);

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<void> fetchProgress(int studentId) async {
    _status = QuranProgressStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      _progressHistory = await _repo.getProgressByStudent(studentId);
      _status = QuranProgressStatus.success;
    } catch (e) {
      _status = QuranProgressStatus.error;
      _errorMessage = 'Failed to load Quran progress history.';
    }
    notifyListeners();
  }

  Future<void> addProgress({
    required int studentId,
    required String surah,
    required int ayahFrom,
    required int ayahTo,
    required String grade,
    String? remarks,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final entry = QuranProgress(
        studentId: studentId,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        surah: surah.trim(),
        ayahFrom: ayahFrom,
        ayahTo: ayahTo,
        grade: grade,
        remarks: remarks?.trim().isEmpty ?? true ? null : remarks?.trim(),
      );
      await _repo.insertQuranProgress(entry);
      await fetchProgress(studentId);
      _isSaving = false;
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
  }
}
