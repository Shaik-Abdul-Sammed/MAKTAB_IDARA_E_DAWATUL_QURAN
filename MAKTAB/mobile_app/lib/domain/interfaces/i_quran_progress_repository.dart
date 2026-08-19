import '../dtos/quran_progress_dto.dart';

abstract class IQuranProgressRepository {
  Future<int> insertQuranProgress(QuranProgressDTO progress);
  Future<List<QuranProgressDTO>> getProgressByStudent(int studentId);
  Future<int> updateQuranProgress(QuranProgressDTO progress);
  Future<int> deleteQuranProgress(int id);
}