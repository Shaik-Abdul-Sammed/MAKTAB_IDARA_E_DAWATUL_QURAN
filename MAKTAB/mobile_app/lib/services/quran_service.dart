import '../repositories/quran_progress_repository.dart';
import '../models/quran_progress.dart';

class QuranService {
  final QuranProgressRepository _repository = QuranProgressRepository();

  Future<void> recordProgress(QuranProgress progress) async {
    await _repository.insertQuranProgress(progress);
  }

  Future<List<QuranProgress>> getStudentProgress(int studentId) async {
    return await _repository.getProgressByStudent(studentId);
  }
  
  Future<String> getLatestSurah(int studentId) async {
    final history = await getStudentProgress(studentId);
    if (history.isEmpty) return 'None';
    // Assuming history is sorted descending by date
    return history.first.surah;
  }
}